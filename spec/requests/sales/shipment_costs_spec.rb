require "rails_helper"

# What a shipment cost (Fernando, 2026-11-12): its lots (2026-11-13; their
# share of each purchase), the haulers' commission of those purchases,
# costs registered from it, expenses of Control financiero assigned to it
# and the trip price.
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

  it "adds the coffee of its lots and their haulers' commission" do
    hauler = create(:hauler)
    invoice = invoice_of(create(:purchase, producer:, hauler:, gross_weight: 146, price_per_pound: 58))
    batch = create(:coffee_batch, warehouse: shipment.warehouse, coffee_state: "wet_parchment", gross_limit: 1_000)
    batch.batch_invoices.create!(invoice:, percent: 50, created_by: admin)
    shipment.update!(batch_ids: [ batch.id ])

    get sales_shipment_path(shipment)
    expect(page.at_css("[data-cost-missing]")).to be_nil
    summary = ShipmentCostSummary.new(shipment)
    expect(summary.coffee).to eq((invoice.total / 2).round(2))
    expect(summary.hauler_commission).to eq((invoice.purchases.first.hauler_commission / 2).round(2))
    expect(figure("coffee")).to eq(ActiveSupport::NumberHelper.number_to_currency(summary.coffee, unit: "L ", precision: 2))
    expect(page.css("[data-shipment-batches] tbody tr").size).to eq(1)
  end

  it "says the coffee's cost is missing without lots" do
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

  it "voiding the shipment lets its lots and expenses go, and its coffee state stays while it has lots" do
    invoice = invoice_of(create(:purchase, producer:))
    batch = create(:coffee_batch, warehouse: shipment.warehouse, coffee_state: "wet_parchment", gross_limit: 1_000)
    batch.batch_invoices.create!(invoice:, percent: 100, created_by: admin)
    shipment.update!(batch_ids: [ batch.id ])
    expense = create(:expense, shipment:)

    expect(shipment.reload.update(coffee_state: "dry_parchment")).to be(false)
    expect(shipment.errors[:base].join).to include("tiene lotes")

    patch void_sales_shipment_path(shipment)
    expect(shipment.reload).to be_voided
    expect(shipment.coffee_batches).to be_empty
    expect(batch.reload.shipment).to be_nil
    expect(expense.reload.shipment).to be_nil
  end
end
