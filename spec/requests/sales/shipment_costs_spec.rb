require "rails_helper"

# What a shipment cost (Fernando, 2026-11-12): its purchase invoices (same
# coffee state, each whole to one shipment), the haulers' commission of
# those purchases, costs registered from it, expenses of Control financiero
# assigned to it and the trip price. Only its cost: the lots do not change.
RSpec.describe "Shipment costs" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }
  let(:shipment) { create(:shipment, coffee_state: "wet_parchment") }

  def page = Nokogiri::HTML(response.body)
  def figure(key) = page.at_css("[data-shipment-cost] [data-cost='#{key}'] dd").text.strip

  def invoice_of(*purchases)
    InvoiceIssuer.new(producer: purchases.first.producer, user: admin, purchase_ids: purchases.map(&:id), payment_status: "pending").call.invoice
  end

  before { sign_in admin }

  it "lists only free invoices of its coffee state to choose, links the marked ones and adds their cost" do
    hauler = create(:hauler)
    wet = invoice_of(create(:purchase, producer:, hauler:, gross_weight: 146, price_per_pound: 58))
    cherry = invoice_of(create(:purchase, producer:, coffee_state: "cherry"))
    taken = invoice_of(create(:purchase, producer:))
    create(:shipment).shipment_invoices.create!(invoice: taken, created_by: admin)

    get new_sales_shipment_invoice_path(shipment)
    expect(response).to have_http_status(:ok)
    rows = page.css("[data-shipment-invoice-choices] tbody tr").map { it["id"] }
    expect(rows).to eq([ "choice_invoice_#{wet.id}" ])

    post sales_shipment_invoices_path(shipment), params: { invoice_ids: [ wet.id, cherry.id, taken.id ] }
    expect(response).to redirect_to(sales_shipment_path(shipment, anchor: "shipment-cost"))
    expect(shipment.reload.invoices).to eq([ wet ])

    get sales_shipment_path(shipment)
    expect(page.at_css("[data-cost-missing]")).to be_nil
    summary = ShipmentCostSummary.new(shipment)
    expect(figure("coffee")).to eq(ActiveSupport::NumberHelper.number_to_currency(wet.total, unit: "L ", precision: 2))
    expect(summary.hauler_commission).to eq(wet.purchases.first.hauler_commission)
    expect(summary.total).to eq(wet.total + summary.hauler_commission)
    expect(page.css("[data-shipment-invoices] a").map { it["href"] }).to include(trading_invoice_path(wet))

    delete sales_shipment_invoice_path(shipment, wet)
    expect(shipment.reload.invoices).to be_empty
  end

  it "says the coffee's cost is missing without invoices" do
    get sales_shipment_path(shipment)
    expect(page.at_css("[data-cost-missing]")).to be_present
    expect(figure("total")).to eq("—")
  end

  it "registers costs from the shipment, out of an account, and adds them with the trip price" do
    account = create(:money_account, opening_balance: 10_000)
    shipment.update!(carrier: create(:carrier), trip_price: 300)
    post sales_shipment_costs_path(shipment), params: { shipment_cost: { concept: "fuel", pricing: "total", amount: "450", paid_on: Time.zone.today,
                                                                         payment_method: "cash", money_account_id: account.id } }
    post sales_shipment_costs_path(shipment), params: { shipment_cost: { concept: "loading", pricing: "per_quintal", weight_side: "origin",
                                                                         weight_kind: "net", quintal_pounds: "100", unit_price: "10",
                                                                         paid_on: Time.zone.today, payment_method: "cash" } }
    costs = shipment.costs.to_a
    expect(costs.map(&:amount)).to eq([ 450, (shipment.origin_net_weight / 100 * 10).round(2) ])
    expect(AccountBalance.new.for(account)).to eq(9_550)
    expect(MoneyMovements.new.all.select { it.source == "shipment_costs" }.map(&:amount_out)).to match_array(costs.map(&:amount))
    expect(ShipmentCostSummary.new(shipment).costs + 300).to eq(costs.sum(&:amount) + 300)

    get sales_shipment_path(shipment)
    expect(figure("costs")).to include(ActiveSupport::NumberHelper.number_to_delimited((costs.sum(&:amount) + 300).round(2)))
    expect(page.css("[data-shipment-costs] tbody tr").size).to eq(3)

    expect(ShipmentPolicy.new(admin, shipment.reload).void?).to be(false)
    delete sales_shipment_cost_path(shipment, costs.first)
    expect(shipment.costs.count).to eq(1)
  end

  it "does not charge on the buyer's weight before it was weighed there" do
    post sales_shipment_costs_path(shipment), params: { shipment_cost: { concept: "freight", pricing: "per_pound", weight_side: "destination",
                                                                         weight_kind: "net", unit_price: "1", paid_on: Time.zone.today,
                                                                         payment_method: "cash" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(shipment.costs).to be_empty
  end

  it "assigns free expenses of Control financiero, and lets them go" do
    free = create(:expense, description: "Peaje a Danlí", amount: 120)
    create(:expense, description: "Otra salida", shipment: create(:shipment))
    create(:expense, kind: "investment", description: "Una inversión")

    get new_sales_shipment_expense_path(shipment)
    expect(page.css("[data-shipment-expense-choices] tbody tr").map { it.text.squish }).to contain_exactly(a_string_including("Peaje a Danlí"))

    post sales_shipment_expenses_path(shipment), params: { expense_ids: [ free.id ] }
    expect(free.reload.shipment).to eq(shipment)
    expect(ShipmentCostSummary.new(shipment).expenses).to eq(120)

    delete sales_shipment_expense_path(shipment, free)
    expect(free.reload.shipment).to be_nil
  end

  it "voiding the shipment lets its invoices and expenses go, and its coffee state stays while it has invoices" do
    invoice = invoice_of(create(:purchase, producer:))
    shipment.shipment_invoices.create!(invoice:, created_by: admin)
    expense = create(:expense, shipment:)

    expect(shipment.update(coffee_state: "dry_parchment")).to be(false)
    expect(shipment.errors[:coffee_state]).to be_present

    patch void_sales_shipment_path(shipment)
    expect(shipment.reload).to be_voided
    expect(shipment.invoices).to be_empty
    expect(expense.reload.shipment).to be_nil
  end

  it "shows the invoices to who reads them, and lets link them to who edits shipments" do
    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "shipments", can_read: true) }
    sign_in reader
    get sales_shipment_path(shipment)
    expect(page.at_css("[data-shipment-cost]")).to be_present
    expect(response.body).not_to include(I18n.t("sales.shipments.cost.invoices.title"))
    get new_sales_shipment_invoice_path(shipment)
    expect(response).to redirect_to(root_path)

    create(:permission, user: reader, module_key: "trading", submodule_key: "invoices", can_read: true)
    get sales_shipment_path(shipment)
    expect(response.body).to include(I18n.t("sales.shipments.cost.invoices.title"))
    expect(response.body).not_to include(I18n.t("sales.shipments.cost.invoices.choose"))
  end
end
