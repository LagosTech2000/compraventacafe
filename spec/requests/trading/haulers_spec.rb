require "rails_helper"

# Carreros (Fernando, 2026-10-16): their screens, the purchase that names
# one, and the payments of their commissions with their receipts.
RSpec.describe "Trading haulers" do
  def user_with(**flags)
    create(:user).tap { |user| create(:permission, user:, module_key: "trading", **flags) }
  end

  let(:user) { user_with(can_read: true, can_create: true, can_update: true, can_destroy: true) }
  def page = Nokogiri::HTML(response.body)

  before { sign_in user }

  it "registers a carrero with its person and price per pound, required" do
    post trading_haulers_path, params: { hauler: { price_per_pound: "",
                                                   person_attributes: { first_names: "Rubén", last_names: "Ordóñez" } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Hauler.count).to eq(0)

    post trading_haulers_path, params: { hauler: { price_per_pound: "0.30",
                                                   person_attributes: { first_names: "Rubén", last_names: "Ordóñez", phone: "9999-0000" } } }
    hauler = Hauler.sole
    expect(response).to redirect_to(trading_hauler_path(hauler))
    expect(hauler).to have_attributes(price_per_pound: BigDecimal("0.3"), active: true)
    expect(hauler.person).to have_attributes(full_name: "Rubén Ordóñez", phone: "99990000")
    expect(AuditEvent.where(auditable: hauler, action: "create")).to exist

    patch trading_hauler_path(hauler), params: { hauler: { price_per_pound: "0.3525", active: "0" } }
    expect(hauler.reload).to have_attributes(price_per_pound: BigDecimal("0.3525"), active: false)
  end

  it "lists them with what they are owed, and shows their purchases, payments and terms" do
    hauler = create(:hauler, person: create(:person, first_names: "Rubén", last_names: "Ordóñez"))
    purchase = create(:purchase, hauler:)
    payment = create(:hauler_payment, hauler:, amount: 1)

    get trading_haulers_path
    row = page.at_css("#hauler_#{hauler.id}")
    expect(row.text.squish).to include("Rubén Ordóñez", "L 0.30", format("L %.2f", purchase.hauler_commission - 1))

    get trading_hauler_path(hauler)
    expect(response.body).to include("Compras que carreó", "Recibo #{payment.display_number}")
    expect(page.at_css("a[href='#{new_trading_hauler_payment_path(hauler)}']")).to be_present
    expect(page.at_css("#hauler_row_purchase_#{purchase.id}").text.squish).to include(purchase.producer.full_name, "L 0.30")
  end

  it "names the carrero on a purchase and shows the commission there" do
    hauler = create(:hauler, price_per_pound: "0.3")
    producer = create(:producer)
    post trading_purchases_path, params: { purchase: { producer_id: producer.id, hauler_id: hauler.id, purchased_at: Time.current,
                                                       coffee_state: "cherry", weight_mode: "single", gross_weight: "1661",
                                                       yield_factor: "1", price_per_pound: "10" } }
    purchase = Purchase.last
    expect(purchase).to have_attributes(hauler:, net_weight: 1_650, hauler_price_per_pound: BigDecimal("0.3"), hauler_commission: 495, total: 16_500)

    get trading_purchase_path(purchase)
    expect(response.body).to include("Carreada por #{hauler.full_name}", "Comisión: L 0.30 por libra neta =", "L 495.00")

    # One from before the change keeps saying how it was calculated.
    purchase.update_columns(hauler_price_per_pound: nil, hauler_commission_percent: 10, hauler_can_price: 50, hauler_cans: 100, hauler_commission: 500)
    get trading_purchase_path(purchase)
    expect(response.body).to include("100.00 latas × L 50.00 × 10 % =", "L 500.00")

    get new_trading_purchase_path
    option = page.at_css("select#purchase_hauler_id option[value='#{hauler.id}']")
    expect(option.to_h).to include("data-price-per-pound" => "0.3")
  end

  it "pays what is owed with a receipt, original and copy, and removes only the last payment" do
    hauler = create(:hauler)
    create(:purchase, hauler:)
    owed = hauler.balance

    post trading_hauler_payments_path(hauler), params: { hauler_payment: { amount: owed + 1, payment_method: "cash", paid_on: Time.zone.today } }
    expect(response).to have_http_status(:unprocessable_content)

    post trading_hauler_payments_path(hauler), params: { hauler_payment: { amount: "10", payment_method: "cash", paid_on: Time.zone.today } }
    first = hauler.payments.sole
    expect(response).to redirect_to(trading_hauler_path(hauler, receipt: first.id))
    expect(first).to have_attributes(amount: 10, balance_after: owed - 10, created_by: user)

    get trading_hauler_payment_path(hauler, first)
    headers = page.css("header.border-b-2")
    expect(headers.map { it.text.squish }).to all(include("Recibo de pago a carrero", first.display_number))
    copy = headers.find { it.text.include?("COPIA") }
    expect(copy.ancestors.any? { |node| node["class"].to_s.split.include?("print:break-before-page") }).to be(true)
    expect(response.body).to include("Queda debiendo el negocio", format("L %.2f", owed - 10))

    post trading_hauler_payments_path(hauler), params: { hauler_payment: { amount: owed - 10, payment_method: "transfer", paid_on: Time.zone.today } }
    expect(hauler.reload.balance).to eq(0)

    delete trading_hauler_payment_path(hauler, first)
    expect(response).to redirect_to(root_path) # not the last one
    expect(hauler.payments.count).to eq(2)
    delete trading_hauler_payment_path(hauler, hauler.payments.last)
    expect(hauler.payments.count).to eq(1)
  end

  it "takes editing in Compra de café to pay, and reading to see" do
    hauler = create(:hauler)
    create(:purchase, hauler:)
    sign_in user_with(can_read: true)

    get trading_hauler_path(hauler)
    expect(response).to have_http_status(:ok)
    expect(page.at_css("a[href='#{new_trading_hauler_payment_path(hauler)}']")).to be_nil
    post trading_hauler_payments_path(hauler), params: { hauler_payment: { amount: "1", payment_method: "cash", paid_on: Time.zone.today } }
    expect(hauler.payments).to be_empty

    sign_in create(:user)
    get trading_haulers_path
    expect(response).to redirect_to(root_path)
  end

  it "makes a person a carrero from the person's form, with Compra de café's permission" do
    admin = create(:user, :admin)
    sign_in admin
    person = create(:person, :client)
    patch administration_person_path(person), params: { person: { client_role: "1", hauler_role: "1",
                                                                  hauler_price_per_pound: "0.22" } }
    expect(person.reload.hauler).to have_attributes(price_per_pound: BigDecimal("0.22"))

    get administration_person_path(person)
    expect(response.body).to include("Carrero")
  end

  it "puts its payments in the money that went out" do
    hauler = create(:hauler, person: create(:person, first_names: "Rubén", last_names: "Ordóñez"))
    create(:purchase, hauler:)
    payment = create(:hauler_payment, hauler:, amount: 5)
    sign_in create(:user, :admin)

    report = CashMovementsReport.new({ period: "this_month" }, user: User.last)
    movement = report.records.find { it.source == "hauler_payments" }
    expect(movement).to have_attributes(amount_out: 5, person: "Rubén Ordóñez", route: [ :trading_hauler_payment_path, hauler.id, payment.id ])
  end
end
