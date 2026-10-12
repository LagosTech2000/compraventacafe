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
end
