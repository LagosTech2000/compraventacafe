require "rails_helper"

# The home page as an operations center (Dashboard): real figures, pending
# work only when there is some, recent records with a link, the usual
# actions, all limited to what the user can see and do.
RSpec.describe "Home page" do
  let(:today) { Time.zone.today }

  def page = Nokogiri::HTML(response.body)
  def figures = page.css("#dashboard-figures ~ dl .stat").to_h { |stat| [ stat.at_css("dt").text, stat.at_css("dd").text.strip ] }
  def actions = page.css("nav[aria-label='Acciones frecuentes'] a").map(&:text)

  def user_with(*module_keys, **flags)
    create(:user).tap do |user|
      module_keys.each { |key| create(:permission, user:, module_key: key, can_read: true, **flags) }
    end
  end

  it "shows the figures, pending work and recent records from the real data" do
    admin = create(:user, :admin)
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:purchase, producer:)
    invoiced = create(:purchase, producer:)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ invoiced.id ], payment_status: "pending").call
    create(:loan, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: today - 90, due_on: today - 1)
    create(:farm)
    sign_in admin

    get root_path
    expect(page.at_css("h1").text).to eq("Hola, #{admin.name}")
    expect(page.at_css("h1 + p").text.squish).to include(I18n.l(today, format: :long))
    expect(figures).to include("Compras de hoy" => "2", "Préstamos por cobrar" => "1", "Fincas activas" => "1", "Pendientes" => "3")

    pending = page.at_css("#dashboard-pending").text.squish
    expect(pending).to include("1 compra sin facturar", "1 factura sin cancelar: falta pagar L 4,120.90", "1 préstamo vencido, deben L 500.00")

    activity = page.css("[aria-labelledby=dashboard-activity] li")
    expect(activity.map { |item| item.text.squish }).to include(a_string_including("Productor nuevo Ana Zelaya"), a_string_including("Préstamo"))
    links = activity.flat_map { |item| item.css("a").map { |link| link["href"] } }
    expect(links).to include(trading_producer_path(producer), trading_purchase_path(invoiced))

    expect(actions).to include("Registrar compra", "Facturar compras", "Nuevo préstamo", "Reportes")
  end

  it "shows only what the user may see and do" do
    reader = user_with("trading")
    create(:purchase)
    create(:loan, cash_amount: 500, monthly_interest_rate: 0)
    sign_in reader

    get root_path
    expect(figures.keys).to include("Compras de hoy", "QQ de la temporada")
    expect(figures.keys).not_to include("Préstamos por cobrar", "Fincas activas")
    activity = page.at_css("[aria-labelledby=dashboard-activity]").text
    expect(activity).to include("Compra")
    expect(activity).not_to include("Préstamo")
    expect(actions).to eq([ "Productores" ]) # reading only: no "Registrar compra" nor "Facturar compras"
  end

  it "sums what the business owes and is owed, only for the modules the user reads (Fernando, 2026-10-25)" do
    admin = create(:user, :admin)
    purchase = create(:purchase, hauler: create(:hauler))
    InvoiceIssuer.new(producer: purchase.producer, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call
    create(:sale) # L 24,108 to collect
    create(:loan, cash_amount: 500, monthly_interest_rate: 0)
    sign_in admin

    get root_path
    debts = Nokogiri::HTML(response.body).at_css("#dashboard-debts")
    owes = debts.at_css("[data-debts=owes]").text.squish
    expect(owes).to include("Facturas por pagar a productores", "Comisiones de carreros")
    expect(owes).to include(format("L %s", ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", Invoice.sole.balance_due + purchase.hauler.balance))))
    expect(debts.at_css("[data-debts=owed]").text.squish).to include("Ventas por cobrar", "L 24,108.00", "Préstamos por cobrar", "L 500.00", "L 24,608.00")

    reader = create(:user).tap { create(:permission, user: it, module_key: "loans", can_read: true) }
    sign_in reader
    get root_path
    debts = Nokogiri::HTML(response.body).at_css("#dashboard-debts")
    expect(debts.text).not_to include("Facturas", "Ventas")
    expect(debts.at_css("[data-debts=owed]").text.squish).to include("Préstamos por cobrar", "L 500.00")
  end

  it "offers creating only in modules the user can see" do
    sign_in user_with("farms").tap { |user| create(:permission, user:, module_key: "loans", can_create: true) }
    get root_path
    expect(actions).not_to include("Nuevo préstamo")
  end

  it "leaves pending work out when there is none, and everything out without modules" do
    sign_in user_with("farms")
    get root_path
    expect(page.at_css("#dashboard-pending")).to be_nil
    expect(figures).to eq("Fincas activas" => "0")

    sign_in create(:user)
    get root_path
    expect(page.at_css("#dashboard-figures")).to be_nil
    expect(page.at_css("[aria-labelledby=dashboard-activity]")).to be_nil
    expect(response.body).to include("Todavía no tienes acceso a ningún módulo")
  end

  describe "who is online and recently active (Presence)" do
    include ActiveSupport::Testing::TimeHelpers

    let(:viewer) { create(:user, name: "Vera Luna") }

    it "keeps the session's last activity, at most once a minute" do
      sign_in viewer
      session = viewer.sessions.sole
      expect(session.last_seen_at).to be_within(5.seconds).of(Time.current)

      travel 30.seconds do
        expect { get root_path }.not_to(change { session.reload.last_seen_at })
      end
      travel 2.minutes do
        get root_path
        expect(session.reload.last_seen_at).to be_within(5.seconds).of(Time.current)
      end
    end

    it "shows the recently active with a grey ring and their last activity on hover" do
      ana = create(:user, name: "Ana Zelaya")
      seen = Time.zone.parse("2026-10-14 09:42")
      ana.sessions.create!(last_seen_at: seen)
      Presence.join(viewer)
      travel_to(seen + 10.minutes) do
        sign_in viewer
        get root_path
      end

      online = page.at_css("#active-users li[data-presence-state=online]#presence_user_#{viewer.id}")
      expect(online.at_css(".online-dot:not(.online-dot-recent)")).to be_present
      expect(online.at_css(".presence-card").text.squish).to eq("VL Vera Luna En línea")

      recent = page.at_css("#active-users li[data-presence-state=recent]#presence_user_#{ana.id}")
      expect(recent.at_css(".online-dot.online-dot-recent")).to be_present
      expect(recent.at_css(".presence-card").text.squish).to eq("AZ Ana Zelaya Última actividad: 09:42")
      expect(recent["aria-describedby"]).to eq("presence_user_#{ana.id}_status")
      expect(page.at_css("#active-users")["aria-label"]).to eq("1 usuario conectado, 1 con actividad en la última hora")
    end

    it "shows the watcher, and only them, each user's page, recent pages and changes, with links" do
      ana = create(:user, name: "Ana Zelaya")
      seen = Time.zone.parse("2026-10-15 10:05")
      ana.sessions.create!(last_seen_at: seen, last_path: "/trading/invoices/12", last_page_title: "Factura 0012")
      PageVisit.record!(user: ana, path: "/trading/purchases", title: "Compras", at: seen - 1.day)
      PageVisit.record!(user: ana, path: "/trading/invoices/12", title: "Factura 0012", at: seen)
      change = AuditEvent.create!(user: ana, user_email: ana.email_address, action: "create", auditable_type: "Zone",
                                  auditable_id: 7, auditable_label: "Morocelí", created_at: seen - 5.minutes)
      Presence.join(ana)
      stub_const("Presence::WATCHER_IDS", [ viewer.id ])

      travel_to(seen + 1.minute) do
        sign_in viewer
        get root_path
      end
      card = page.at_css("#active-users li[data-presence-state=online]#presence_user_#{ana.id} .presence-card")
      expect(card.at_css("[data-presence-page]").text.squish).to eq("Última actividad: 10:05 Está en: Factura 0012 /trading/invoices/12")
      expect(card.at_css("[data-presence-page] a[href='/trading/invoices/12'][data-turbo-frame='_top']")).to be_present

      visits = card.css("[data-presence-visits] a")
      expect(visits.map { it["href"] }).to eq([ "/trading/invoices/12", "/trading/purchases" ])
      expect(visits.map { it.text.squish }).to eq([ "10:05 Factura 0012 /trading/invoices/12", "14 de oct 10:05 Compras /trading/purchases" ])

      link = card.at_css("[data-presence-changes] a")
      expect(link["href"]).to eq(administration_audit_event_path(change))
      expect(link["data-turbo-frame"]).to eq("modal")
      expect(link.text.squish).to eq("10:00 Creó la zona #7 (Morocelí)")
      expect(response.body).to include(Turbo::StreamsChannel.signed_stream_name(Presence::WATCH_STREAM))

      sign_in create(:user, name: "Otro Usuario")
      get root_path
      expect(page.at_css("#active-users li[data-presence-state=online]#presence_user_#{ana.id} .presence-card").text.squish).to eq("AZ Ana Zelaya En línea")
      expect(page.at_css("[data-presence-page], [data-presence-visits], [data-presence-changes]")).to be_nil
      expect(response.body).not_to include("/trading/invoices/12")
      expect(response.body).not_to include(Turbo::StreamsChannel.signed_stream_name(Presence::WATCH_STREAM))
    end
  end
end
