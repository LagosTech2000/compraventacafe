require "rails_helper"

# The demo flow: register producer and purchase, invoice it, print, pay,
# and see it in the daily close.
RSpec.describe "Trading purchase flow" do
  let(:user) do
    create(:user).tap do |u|
      create(:permission, user: u, module_key: "trading", can_read: true, can_create: true, can_update: true, can_destroy: true)
    end
  end
  let(:zone) { create(:zone, name: "Buenas Noches") }

  before { sign_in user }

  it "creates a zone" do
    post trading_zones_path, params: { zone: { name: "  Pueblo  Nuevo " } }
    expect(response).to redirect_to(trading_zones_path)
    expect(Zone.last.name).to eq("Pueblo Nuevo")
  end

  it "rejects a duplicate zone regardless of case" do
    create(:zone, name: "Las Labranzas")
    post trading_zones_path, params: { zone: { name: "las labranzas" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "saves a purchase with a farm of its producer and shows it, and refuses another producer's" do
    producer = create(:producer)
    farm = producer.farms.create!(name: "El Mirador")
    other = create(:producer).farms.create!(name: "Las Brisas")
    attributes = { producer_id: producer.id, purchased_at: Time.current, coffee_state: "wet_parchment", weight_mode: "single",
                   gross_weight: "146", humidity_percent: "51", damage_percent: "0", price_per_pound: "58" }

    post trading_purchases_path, params: { purchase: attributes.merge(farm_id: farm.id) }
    purchase = Purchase.last
    expect(purchase.farm).to eq(farm)
    get trading_purchase_path(purchase)
    expect(response.body).to include("El Mirador")

    post trading_purchases_path, params: { purchase: attributes.merge(farm_id: other.id) }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("no es una finca de este productor")
  end

  it "creates a producer's farm from the purchase form, set to that producer" do
    producer = create(:producer)
    create(:permission, user:, module_key: "farms", can_read: true, can_create: true)
    get new_farms_farm_path(picker: 1, producer_id: producer.id), headers: { "Turbo-Frame" => "modal" }
    expect(response.body).to include(producer.full_name)

    post farms_farms_path, headers: { "Turbo-Frame" => "modal" }, params: { picker: "1", farm: { name: "El Cerro", producer_id: producer.id } }
    expect(producer.farms.pluck(:name)).to eq([ "El Cerro" ])
    detail = Nokogiri::HTML(response.body).at_css("[data-controller='modal-result']")["data-modal-result-detail-value"]
    expect(JSON.parse(detail)).to include("name" => "El Cerro", "producer_id" => producer.id)
  end

  it "registers a producer from the purchase form's modal and hands it to the picker" do
    post trading_producers_path, headers: { "Turbo-Frame" => "modal" }, params: {
      picker: "1",
      producer: { kind: "intermediary", new_farm_name: "El Cerro",
                  person_attributes: { first_names: "Pedro", last_names: "Martínez", phone: "9999-0000", zone_id: zone.id,
                                       client_role: "0", collaborator_role: "1" } }
    }
    producer = Producer.last
    expect(producer).to have_attributes(kind: "intermediary", farm_names: "El Cerro", zone: zone)
    expect(producer.person).to have_attributes(phone: "99990000", collaborator?: true, client?: false)

    result = Nokogiri::HTML(response.body).at_css("turbo-frame#modal [data-controller='modal-result']")
    expect(result["data-modal-result-event-value"]).to eq("producer:created")
    expect(JSON.parse(result["data-modal-result-detail-value"])).to eq("id" => producer.id, "label" => "Pedro Martínez", "zone_id" => zone.id,
                                                                       "farms" => [ [ producer.farms.sole.id, "El Cerro" ] ],
                                                                       "missing" => [ "DNI", "RTN", "Correo electrónico", "Dirección", "Clave IHCAFE" ])
    expect(result["data-modal-result-refresh-value"]).to eq("false")
    expect(flash[:notice]).to be_nil
  end

  it "shows nested person errors in Spanish" do
    post trading_producers_path, params: { producer: { kind: "producer", person_attributes: { first_names: "", last_names: "" } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Nombres no puede estar en blanco")
  end

  it "prefills the purchase form with the producer, its zone, today and 51% humidity" do
    producer = create(:producer, zone:)
    get new_trading_purchase_path(producer_id: producer.id)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("#purchase_producer_id")["value"]).to eq(producer.id.to_s)
    expect(page.at_css("#purchase_zone_id option[selected]").text).to eq("Buenas Noches")
    expect(page.at_css("#purchase_humidity_percent")["value"]).to eq("51")
    expect(page.at_css("#purchase_purchased_at")["type"]).to eq("datetime-local")
    expect(page.at_css("#purchase_purchased_at")["value"]).to start_with("#{Time.zone.today.iso8601}T")
  end

  it "registers a purchase with the calculation and who entered it" do
    producer = create(:producer)
    post trading_purchases_path, params: {
      purchase: { producer_id: producer.id, zone_id: zone.id, purchased_at: Time.zone.today, coffee_state: "wet_parchment",
                  gross_weight: "146", humidity_percent: "51", damage_percent: "0", price_per_pound: "58", observations: "Pulpa" }
    }
    purchase = Purchase.last
    expect(purchase).to have_attributes(net_weight: BigDecimal("71.05"), total: BigDecimal("4120.90"), created_by: user)
    expect(response).to redirect_to(new_trading_purchase_path(detail: purchase.id))

    follow_redirect!
    frame = Nokogiri::HTML(response.body).at_css("dialog turbo-frame#modal")
    expect(frame["src"]).to eq(trading_purchase_path(purchase, created: 1))

    # The detail of the purchase just registered focuses "Facturar ahora": Enter invoices.
    get trading_purchase_path(purchase, created: 1), headers: { "Turbo-Frame" => "modal" }
    expect(Nokogiri::HTML(response.body).at_css("a[autofocus]").text).to eq("Facturar ahora")
  end

  it "registers a purchase by weighings and shows them on its detail" do
    producer = create(:producer)
    post trading_purchases_path, params: {
      purchase: { producer_id: producer.id, purchased_at: Time.zone.now, coffee_state: "wet_parchment", weight_mode: "weighings",
                  gross_weight: "", humidity_percent: "51", damage_percent: "0", price_per_pound: "58",
                  weighings_attributes: { "0" => { gross_weight: "300", sacks: "2" }, "1" => { gross_weight: "300", sacks: "2" },
                                          "2" => { gross_weight: "300", sacks: "2" }, "3" => { gross_weight: "", sacks: "" } } }
    }
    purchase = Purchase.last
    expect(purchase).to have_attributes(weight_mode: "weighings", gross_weight: 900, sacks: 6, tare: 6)
    expect(purchase.weighings.count).to eq(3)

    get edit_trading_purchase_path(purchase)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("input#purchase_gross_weight")["readonly"]).to be_present
    expect(page.css("input[name^='purchase[weighings_attributes]'][name$='[sacks]']").size).to eq(4) # 3 + template

    get trading_purchase_path(purchase)
    expect(response.body).to include("Por pesadas", "Pesadas")
  end

  it "filters purchases and invoices by the seasons that have purchases" do
    old = create(:purchase, purchased_at: Time.zone.local(2025, 10, 1, 9))
    current = create(:purchase, purchased_at: Time.zone.local(2026, 9, 15, 9))
    old_invoice = InvoiceIssuer.new(producer: old.producer, user:, purchase_ids: [ old.id ], payment_status: "pending").call.invoice

    get trading_purchases_path(season_year: 2025, from: "", to: "")
    expect(response.body).to include(dom_id_for(old))
    expect(response.body).not_to include(dom_id_for(current))
    options = Nokogiri::HTML(response.body).css("select#season_year option").map(&:text)
    expect(options).to eq([ "Todas las temporadas", "Temporada 2026", "Temporada 2025" ])

    get trading_invoices_path(season_year: 2026)
    expect(response.body).not_to include(trading_invoice_path(old_invoice))
    get trading_invoices_path(season_year: 2025)
    expect(response.body).to include(trading_invoice_path(old_invoice))
  end

  it "rejects a purchase without producer, in Spanish" do
    post trading_purchases_path, params: { purchase: { gross_weight: "146", humidity_percent: "51", price_per_pound: "58", coffee_state: "cherry", purchased_at: Time.zone.today } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Productor debe existir")
  end

  it "invoices, prints original and copy, and is paid" do
    producer = create(:producer, zone:)
    purchases = create_list(:purchase, 2, producer:)

    post trading_invoices_path, params: { producer_id: producer.id, invoice: { purchase_ids: purchases.map(&:id), payment_status: "pending" } }
    invoice = Invoice.last
    expect(response).to redirect_to(trading_invoice_path(invoice))

    get trading_invoice_path(invoice)
    expect(response.body).to include("ORIGINAL", "COPIA", "Compra de Café el Rey David", "Mata de Plátano, Moroceli", "Firma de quien factura")
    expect(response.body).to include("L 8,241.80")
    expect(response.body).to include("Facturado por: #{user.name}")

    post trading_invoice_payments_path(invoice), params: { invoice_payment: { amount: "8241.80", payment_method: "cash", paid_on: Time.zone.today } }
    expect(invoice.reload).to be_paid
  end

  describe "paying an invoice in parts" do
    let(:producer) { create(:producer, zone:) }
    let(:invoice) { InvoiceIssuer.new(producer:, user:, purchase_ids: [ create(:purchase, producer:).id ], payment_status: "pending").call.invoice }

    def pay(amount, method = "cash", on: Time.zone.today)
      post trading_invoice_payments_path(invoice), params: { invoice_payment: { amount:, payment_method: method, paid_on: on } }
    end

    it "is partial with a payment that does not cover it, and paid once they do" do
      get new_trading_invoice_payment_path(invoice), headers: { "Turbo-Frame" => "modal" }
      expect(Nokogiri::HTML(response.body).at_css("#invoice_payment_amount")["value"]).to eq("4120.9")

      pay("1000")
      payment = invoice.payments.last
      expect(response).to redirect_to(trading_invoice_path(invoice, receipt: payment.id))
      expect(invoice.reload).to have_attributes(payment_status: "partial", paid_on: nil)
      expect(flash[:notice]).to eq("Abono registrado.")

      get trading_invoice_path(invoice)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#invoice-payments").parent.text.squish).to include("A pagar: L 4,120.90", "Abonado: L 1,000.00", "Saldo: L 3,120.90")
      expect(page.css("article").first.text.squish).to include("Pago parcial", "Abono #{payment.display_number}", "Saldo pendiente L 3,120.90")

      get trading_invoice_payment_path(invoice, payment)
      receipt = Nokogiri::HTML(response.body).at_css("article").text.squish
      expect(receipt).to include("Recibo de pago #{payment.display_number}", "Monto pagado L 1,000.00", "Saldo pendiente L 3,120.90", "Recibí conforme")

      pay("3120.90", "transfer")
      expect(invoice.reload).to have_attributes(payment_status: "paid", paid_on: Time.zone.today, payment_method: nil)
      expect(invoice.human_payment_method).to eq("Varias formas")
    end

    it "refuses more than the balance, in Spanish, and keeps the invoice as it was" do
      pay("5000")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Monto es mayor que el saldo de la factura (L 4,120.90)")
      expect(invoice.reload).to be_pending
    end

    it "removes only the latest payment, which brings the balance back" do
      pay("1000")
      pay("500")
      first, last = invoice.payments.to_a
      delete trading_invoice_payment_path(invoice, first)
      expect(invoice.payments.count).to eq(2)

      delete trading_invoice_payment_path(invoice, last)
      expect(invoice.reload.payments.count).to eq(1)
      expect(invoice.balance_due).to eq(BigDecimal("3120.90"))
      expect(invoice).to be_partial
    end

    it "can be invoiced with a partial payment on the spot" do
      purchase = create(:purchase, producer:)
      post trading_invoices_path, params: { producer_id: producer.id,
                                            invoice: { purchase_ids: [ purchase.id ], payment_status: "partial", payment_method: "cash",
                                                       paid_on: Time.zone.today, amount: "2000" } }
      created = Invoice.last
      expect(created).to have_attributes(payment_status: "partial", paid_total: 2000, balance_due: BigDecimal("2120.90"))

      other = create(:purchase, producer:)
      post trading_invoices_path, params: { producer_id: producer.id,
                                            invoice: { purchase_ids: [ other.id ], payment_status: "partial", payment_method: "cash", amount: "4120.90" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Un pago parcial debe ser menor que el total a pagar")
      expect(other.reload.invoice).to be_nil
    end

    it "lists partial invoices with what is left, in the lists and the module home" do
      pay("1000")
      get trading_invoices_path(payment_status: "unpaid")
      expect(Nokogiri::HTML(response.body).css("tbody tr").map { |row| row["id"] }).to eq([ "invoice_#{invoice.id}" ])
      get trading_invoices_path(payment_status: "pending")
      expect(Nokogiri::HTML(response.body).css("tbody tr")).to be_empty

      get trading_root_path
      expect(Nokogiri::HTML(response.body).css("main ol > li")[2].text.squish).to include("1 factura sin cancelar: falta pagar L 3,120.90")

      get trading_producer_path(producer)
      expect(Nokogiri::HTML(response.body).at_css("section[aria-labelledby=producer-pending]").text.squish)
        .to include("1 factura sin cancelar (saldo) L 3,120.90")
    end

    it "lets loans be paid with coffee only up to what the invoice still owes" do
      create(:permission, user:, module_key: "loans", can_read: true, can_create: true)
      loan = create(:loan, person: producer.person, cash_amount: 10_000, monthly_interest_rate: 0)
      pay("4000")
      purchase = invoice.purchases.first
      expect(purchase.available_for_loans).to eq(BigDecimal("120.90"))

      post trading_purchase_loan_settlement_path(purchase), params: { purchase_loan_settlement: { paid_on: Time.zone.today, amounts: { loan.id.to_s => "120.90" } } }
      expect(invoice.reload).to be_paid
      expect(invoice.balance_due).to eq(0)
    end
  end

  it "shows on the invoice what damage took off, in pounds and lempiras" do
    producer = create(:producer, zone:)
    purchase = create(:purchase, producer:, gross_weight: 146, humidity_percent: 51, damage_percent: 2.5, price_per_pound: 58)
    get new_trading_invoice_path(producer_id: producer.id)
    expect(response.body).to include("Daño (lb)", "1.78", "L 103.24")

    post trading_invoices_path, params: { producer_id: producer.id, invoice: { purchase_ids: [ purchase.id ], payment_status: "pending" } }
    get trading_invoice_path(Invoice.last)
    receipt = Nokogiri::HTML(response.body).at_css("article")
    expect(receipt.at_css("thead").text).to include("Daño (lb)", "Daño (L)")
    expect(receipt.at_css("tbody tr").text.squish).to include("1.78 2.50 % L 103.24")
    expect(receipt.at_css("tfoot").text.squish).to include("1.78 L 103.24")
  end

  it "does not print the notice of the invoice just created" do
    producer = create(:producer)
    purchase = create(:purchase, producer:)
    post trading_invoices_path, params: { producer_id: producer.id, invoice: { purchase_ids: [ purchase.id ], payment_status: "pending" } }
    follow_redirect!
    notice = Nokogiri::HTML(response.body).at_css("#notice")
    expect(notice.text).to include("Factura creada.")
    expect(notice.ancestors("div").first["class"]).to include("print:hidden")
  end

  it "prints the original and the copy on separate pages, each saying which one it is" do
    invoice = create(:invoice)
    get trading_invoice_path(invoice)
    page = Nokogiri::HTML(response.body)
    copy = page.at_css("div.print\\:break-before-page article")
    expect(copy.text).to include("COPIA")
    markers = page.css("thead tr.print\\:table-row").map { |row| row.text.squish }
    expect(markers).to eq([ "Factura #{invoice.display_number} · ORIGINAL", "Factura #{invoice.display_number} · COPIA" ])
    expect(response.body).not_to include("border-dashed")
  end

  it "does not let an invoiced purchase be edited" do
    purchase = create(:invoice).purchases.first
    patch trading_purchase_path(purchase), params: { purchase: { price_per_pound: 1 } }
    expect(response).to redirect_to(root_path)
    expect(purchase.reload.price_per_pound).to eq(58)
  end

  it "shows the daily close and the purchases of a date" do
    create(:purchase, purchased_at: Date.new(2026, 1, 15), gross_weight: 146)
    get trading_daily_close_path(date: "2026-01-15")
    expect(response.body).to include("15 de enero de 2026", "146.00", "L 4,120.90")
    get trading_purchases_path(date: "no-es-fecha")
    expect(response).to have_http_status(:ok)
  end

  it "opens the daily close on today and changes date without a button" do
    get trading_daily_close_path
    form = Nokogiri::HTML(response.body).at_css("form[data-controller='auto-submit']")
    expect(form.at_css("input[type=date]")["value"]).to eq(Time.zone.today.iso8601)
    expect(form.at_css("input[type=date]")["data-action"]).to eq("change->auto-submit#submit")
    expect(form.css("input[type=submit], button")).to be_empty
  end

  it "prints the daily close as a report grouped by payment state with subtotals" do
    create(:purchase, gross_weight: 146)
    create(:invoice).purchases.first.invoice.mark_paid(method: "cash", on: Time.zone.today)
    get trading_daily_close_path

    report = Nokogiri::HTML(response.body).at_css("section.print\\:block")
    expect(report.text).to include("Compra de Café el Rey David", "Cierre diario", "Subtotal")
    expect(report.css("caption").map { |caption| caption.text.squish }).to eq([ "Canceladas (1)", "Sin facturar (1)", "Por productor" ])
    expect(report.text).to include("Generado por #{user.name}")
    expect(report.css("a")).to be_empty
  end

  it "details the day by producer, the one who sold the most first, on screen and printed" do
    big = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    small = create(:producer, person: create(:person, first_names: "Bruno", last_names: "Aguilar"))
    create(:purchase, producer: small, gross_weight: 146)
    2.times { create(:purchase, producer: big, gross_weight: 1000) }
    paid = create(:purchase, producer: big, gross_weight: 146)
    InvoiceIssuer.new(producer: big, user:, purchase_ids: [ paid.id ], payment_status: "paid", payment_method: "cash").call
    create(:purchase, producer: small, purchased_at: 1.day.ago)

    get trading_daily_close_path
    page = Nokogiri::HTML(response.body)
    days = page.css("#daily-close-producers ~ div > details")
    expect(days.map { |day| day.at_css("summary span.font-semibold").text }).to eq([ "Ana Zelaya", "Bruno Aguilar" ])
    expect(days.first.at_css("summary").text.squish).to include("3 compras", "Total compradoL 60,563.02", "CanceladasL 4,120.90", "Sin facturarL 56,442.12")
    expect(days.first.css("tr[id^=purchase_]").size).to eq(3)
    expect(days.last.at_css("summary").text.squish).to include("1 compra")

    printed = page.at_css("section.print\\:block").css("table").last
    expect(printed.at_css("caption").text).to eq("Por productor")
    expect(printed.css("tbody tr").map { |row| row.at_css("td").text }).to eq([ "Ana Zelaya", "Bruno Aguilar" ])
  end

  it "suggests today's purchases by producer in the reports" do
    preset = ReportPreset.all.find { |item| item.key == :purchases_today_by_producer }
    expect(preset.params).to eq(period: "today", group: "producer")
    expect(preset.title).to eq("Compras de hoy por productor")
  end

  it "guides the next step from the purchase detail" do
    purchase = create(:purchase)
    get trading_purchase_path(purchase)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("[aria-current=step]").text).to include("Facturada", "Siguiente")
    invoice_now = page.css("a").find { |a| a.text == "Facturar ahora" }
    expect(invoice_now["href"]).to eq(new_trading_invoice_path(producer_id: purchase.producer_id))

    invoice = InvoiceIssuer.new(producer: purchase.producer, user:, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
    get trading_purchase_path(purchase)
    expect(response.body).to include("Registrar abono a la factura #{invoice.display_number}")

    get trading_invoice_path(invoice)
    expect(Nokogiri::HTML(response.body).at_css("[aria-current=step]").text).to include("Cancelada")
    invoice.mark_paid(method: "cash", on: Time.zone.today)
    get trading_invoice_path(invoice)
    expect(response.body).to include("Ciclo completo")
  end

  it "shows what's next on the module home, highlighting pending work" do
    create_list(:purchase, 2)
    create(:invoice)
    get trading_root_path
    steps = Nokogiri::HTML(response.body).css("main ol > li").map { |li| li.text.squish }
    expect(steps[0]).to include("Paso 1", "3 compras registradas hoy")
    expect(steps[1]).to include("Paso 2", "2 compras sin facturar")
    expect(steps[2]).to include("Paso 3", "1 factura sin cancelar")
    expect(steps[3]).to include("Paso 4", "Cerrar el día")
  end

  it "keeps a read-only user from registering purchases" do
    reader = create(:user).tap { |u| create(:permission, user: u, module_key: "trading", can_read: true) }
    sign_in reader
    get trading_root_path
    expect(response.body).not_to include(new_trading_purchase_path)
    expect { post trading_purchases_path, params: { purchase: { gross_weight: 1 } } }.not_to change(Purchase, :count)
  end

  describe "coffee states" do
    it "registers cherry with the yield and shows its quintals" do
      producer = create(:producer)
      post trading_purchases_path, params: {
        purchase: { producer_id: producer.id, purchased_at: Time.zone.today, coffee_state: "cherry",
                    gross_weight: "1000", yield_factor: "0.186", price_per_pound: "10" }
      }
      purchase = Purchase.last
      expect(purchase).to have_attributes(humidity_percent: nil, yield_factor: BigDecimal("0.186"), net_weight: BigDecimal("184.70"))

      get trading_purchase_path(purchase)
      expect(response.body).to include("Rendimiento", "0.186", "Quintales (QQ)", "1.48")
    end

    it "gives the calculator the defaults of each state and hides the fields that do not apply" do
      get new_trading_purchase_path
      page = Nokogiri::HTML(response.body)
      defaults = JSON.parse(page.at_css("form[data-purchase-calculator-defaults-value]")["data-purchase-calculator-defaults-value"])
      expect(defaults).to eq("cherry" => { "yield_factor" => "0.186" },
                             "wet_parchment" => { "humidity_percent" => 51, "damage_percent" => 0 },
                             "dry_parchment" => { "humidity_percent" => 12, "damage_percent" => 0 })
      expect(page.at_css("#purchase_damage_percent")["value"]).to eq("0")
      expect(page.at_css("#purchase_yield_factor")["disabled"]).to be_present
      expect(page.at_css("#purchase_yield_factor").ancestors("div").first.key?("hidden")).to be(true)
    end
  end

  describe "voiding" do
    it "voids a purchase and hides it from the list unless asked for" do
      purchase = create(:purchase)
      patch void_trading_purchase_path(purchase), headers: { "HTTP_REFERER" => trading_purchases_url }
      expect(response).to redirect_to(trading_purchases_url)
      expect(purchase.reload).to have_attributes(voided?: true, voided_by: user)

      get trading_purchases_path
      expect(response.body).not_to include(dom_id_for(purchase))
      get trading_purchases_path(show_voided: "1")
      expect(response.body).to include(dom_id_for(purchase), "Anulada")
    end

    it "leaves voided purchases out of the totals, the daily close and invoicing" do
      kept = create(:purchase)
      create(:purchase, producer: kept.producer).void!(user)

      expect(DailyClose.new(Time.zone.today).purchases).to eq([ kept ])
      get new_trading_invoice_path(producer_id: kept.producer_id)
      expect(Nokogiri::HTML(response.body).css("input[name='invoice[purchase_ids][]']").map { |i| i["value"] }).to eq([ kept.id.to_s ])
    end

    it "voids and adds purchases from the invoicing screen" do
      purchase = create(:purchase)
      get new_trading_invoice_path(producer_id: purchase.producer_id)
      page = Nokogiri::HTML(response.body)
      void_button = page.css("button").find { |b| b.text == "Anular" }
      expect(page.at_css("form##{void_button["form"]}")["action"]).to eq(void_trading_purchase_path(purchase))
      new_purchase = page.css("a").find { |a| a.text == "Nueva compra para este productor" }
      expect(new_purchase["href"]).to eq(new_trading_purchase_path(producer_id: purchase.producer_id))
      expect(new_purchase["data-turbo-frame"]).to eq("modal")
    end

    it "closes the modal and refreshes the page behind when a purchase is registered in it" do
      producer = create(:producer)
      post trading_purchases_path, headers: { "Turbo-Frame" => "modal" }, params: {
        purchase: { producer_id: producer.id, purchased_at: Time.zone.today, coffee_state: "wet_parchment",
                    gross_weight: "146", humidity_percent: "51", damage_percent: "2", price_per_pound: "58" }
      }
      result = Nokogiri::HTML(response.body).at_css("turbo-frame#modal [data-controller='modal-result']")
      expect(result["data-modal-result-refresh-value"]).to eq("true")
    end
  end

  it "registers the moment of the purchase and shows it with its time everywhere" do
    producer = create(:producer)
    post trading_purchases_path, params: {
      purchase: { producer_id: producer.id, purchased_at: "#{Time.zone.today.iso8601}T07:45", coffee_state: "wet_parchment",
                  gross_weight: "146", humidity_percent: "51", damage_percent: "0", price_per_pound: "58" }
    }
    purchase = Purchase.last
    expect(purchase.purchased_at).to eq(Time.zone.today.in_time_zone.change(hour: 7, min: 45))
    stamp = "#{I18n.l(Time.zone.today)} 07:45"

    get trading_purchases_path
    expect(response.body).to include(stamp)
    get trading_purchase_path(purchase)
    expect(response.body).to include("07:45")
    get new_trading_invoice_path(producer_id: producer.id)
    expect(response.body).to include(stamp)
  end

  it "counts a purchase late in the day in that day's list and close" do
    late = create(:purchase, purchased_at: Time.zone.today.in_time_zone.change(hour: 23, min: 50))
    create(:purchase, purchased_at: Time.zone.today.in_time_zone.yesterday.change(hour: 23, min: 50))
    expect(PurchaseFilter.new(ActionController::Parameters.new).apply(Purchase.all)).to eq([ late ])
    expect(DailyClose.new(Time.zone.today).purchases).to eq([ late ])
  end

  it "searches producers by name, DNI or RTN" do
    producer = create(:producer, person: create(:person, first_names: "Josiel", last_names: "Duarte"))
    create(:producer)
    get trading_producers_path(q: "josiel", kind: "", zone_id: "")
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css("tbody tr").map { |row| row["id"] }).to eq([ "producer_#{producer.id}" ])
  end

  describe "producer page" do
    it "pins the quintals and splits summary, purchases and invoices into tabs" do
      producer = create(:producer, ihcafe_code: "08-04-01234")
      create(:purchase, producer:, net_weight: 0, gross_weight: 1000, humidity_percent: 51) # 486.57 lb net
      create(:purchase, producer:, purchased_at: Season.current.starts_on - 1)
      create(:purchase, producer:).void!(user)

      get trading_producer_path(producer)
      page = Nokogiri::HTML(response.body)
      stats = page.css("dl .stat").to_h { |stat| [ stat.at_css("dt").text, stat.at_css("dd").text ] }
      expect(stats).to include("QQ de la temporada" => "3.89", "Compras de la temporada" => "1")
      expect(stats["QQ de todas las temporadas"]).to eq("4.46")
      expect(page.css("nav a[aria-current=page]").map(&:text)).to include("Resumen")
      expect(page.at_css("aside").text).to include("Clave IHCAFE", "08-04-01234", "DNI", "2 compras sin facturar")
      expect(page.css("#producer-seasons ~ table tbody tr").size).to eq(2)
      expect(page.css("tr[id^=purchase_]").size).to eq(2) # latest purchases, without the voided one

      get trading_producer_path(producer, season_year: "", tab: "purchases")
      expect(Nokogiri::HTML(response.body).css("tr[id^=purchase_]").size).to eq(2)

      get trading_producer_path(producer, tab: "invoices")
      expect(response.body).to include("No hay facturas que coincidan con los filtros.")
    end

    it "offers the full page only inside the modal" do
      producer = create(:producer)
      get trading_producer_path(producer), headers: { "Turbo-Frame" => "modal" }
      link = Nokogiri::HTML(response.body).css("a").find { |a| a.text == "Ver detalle completo" }
      expect(link["href"]).to eq(trading_producer_path(producer, tab: "summary"))
      expect(link["data-turbo-frame"]).to eq("_top")

      get trading_producer_path(producer)
      expect(Nokogiri::HTML(response.body).css("a").map(&:text)).not_to include("Ver detalle completo")
    end

    it "shows what the producer owes in loans only to who can see loans" do
      producer = create(:producer)
      create(:loan, person: producer.person, cash_amount: 500, monthly_interest_rate: 0)

      get trading_producer_path(producer)
      expect(response.body).not_to include("Estado de cuenta")

      create(:permission, user:, module_key: "loans", can_read: true)
      get trading_producer_path(producer)
      expect(Nokogiri::HTML(response.body).at_css("section[aria-labelledby=producer-loans]").text.squish).to include("Debe hoy L 500.00")
    end
  end

  describe "IHCAFE code" do
    it "is saved from the form in XX-XX-XXXXX and finds the producer" do
      post trading_producers_path, params: { producer: { kind: "producer", ihcafe_code: "08 04 a1234",
                                                         person_attributes: { first_names: "Ana", last_names: "Paz" } } }
      producer = Producer.last
      expect(producer.ihcafe_code).to eq("08-04-A1234")

      get trading_producers_path(q: "a1234")
      expect(Nokogiri::HTML(response.body).css("tbody tr").map { |row| row["id"] }).to eq([ "producer_#{producer.id}" ])
    end
  end

  describe "paying loans with a purchase" do
    let(:loans_user) do
      user.tap { |u| create(:permission, user: u, module_key: "loans", can_read: true, can_create: true, can_update: true, can_destroy: true) }
    end
    let(:producer) { create(:producer) }
    let!(:loan) { create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0) }

    before { loans_user }

    it "shows the debt on the purchase, settles it and takes it off the invoice" do
      purchase = create(:purchase, producer:)
      get trading_purchase_path(purchase)
      expect(Nokogiri::HTML(response.body).at_css("#purchase-loans").parent.text.squish).to include("debe L 1,000.00 en 1 préstamo")
      link = Nokogiri::HTML(response.body).css("a").find { |a| a.text == "Abonar con esta compra" }
      expect(link["href"]).to eq(new_trading_purchase_loan_settlement_path(purchase))

      get new_trading_purchase_loan_settlement_path(purchase), headers: { "Turbo-Frame" => "modal_2" }
      expect(response.body).to include("Préstamo #{loan.id}", "Saldar", "Disponible para abonar")

      post trading_purchase_loan_settlement_path(purchase), headers: { "Turbo-Frame" => "modal_2" },
           params: { purchase_loan_settlement: { paid_on: Time.zone.today.iso8601, amounts: { loan.id.to_s => "1000" } } }
      expect(Nokogiri::HTML(response.body).at_css("[data-controller='modal-result']")).to be_present
      expect(loan.reload).to be_paid_off
      expect(flash[:notice]).to eq("Abono de L 1,000.00 registrado con la compra.")

      get trading_purchase_path(purchase)
      expect(response.body).to include("A pagar al productor", "L 3,120.90")

      post trading_invoices_path, params: { producer_id: producer.id, invoice: { purchase_ids: [ purchase.id ], payment_status: "pending" } }
      get trading_invoice_path(Invoice.last)
      expect(response.body).to include("Abono a préstamo N.º #{loan.id}", "Total a pagar", "L 3,120.90")

      get loans_loan_path(loan)
      expect(response.body).to include("Con café · compra #{purchase.id}")
    end

    it "shows the settlement errors in Spanish" do
      purchase = create(:purchase, producer:)
      post trading_purchase_loan_settlement_path(purchase), params: { purchase_loan_settlement: { amounts: { loan.id.to_s => "" } } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Escribe cuánto abonar al menos a un préstamo.")
    end

    it "takes both modules: without loans permission there is no button nor access" do
      Permission.where(user:, module_key: "loans").delete_all
      purchase = create(:purchase, producer:)
      get trading_purchase_path(purchase)
      expect(Nokogiri::HTML(response.body).css("a").map(&:text)).not_to include("Abonar con esta compra")
      post trading_purchase_loan_settlement_path(purchase), params: { purchase_loan_settlement: { amounts: { loan.id.to_s => "10" } } }
      expect(LoanPayment.count).to eq(0)
    end
  end

  def dom_id_for(purchase) = "id=\"purchase_#{purchase.id}\""
end
