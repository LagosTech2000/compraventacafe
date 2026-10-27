require "rails_helper"

# Registering what processing cost (client, 2026-10-26): from the process's
# detail, out of an account, in Control financiero's movements.
RSpec.describe "Processing costs" do
  let(:admin) { create(:user, :admin) }
  let(:site) { create(:processing_site, name: "Secadora El Pino") }
  let(:conversion) { create(:coffee_conversion, :finished, from_state: "wet_parchment", input_gross_weight: 1_000, weighed_at: 3.hours.ago, processing_site: site) }
  let(:account) { create(:money_account, name: "Caja", opening_balance: 10_000) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "registers a cost per quintal, shows it on the process and takes it out of the account" do
    get new_sales_coffee_conversion_cost_path(conversion)
    expect(response).to have_http_status(:ok)

    post sales_coffee_conversion_costs_path(conversion), params: { processing_cost: {
      concept: "drying", pricing: "per_quintal", weight_side: "input", weight_kind: "gross", quintal_pounds: "100", unit_price: "25",
      paid_on: Time.zone.today, payment_method: "cash", money_account_id: account.id } }
    cost = ProcessingCost.sole
    expect(cost).to have_attributes(base_pounds: 1_000, quantity: 10, amount: 250, created_by: admin)
    expect(AuditEvent.where(auditable: cost, action: "create")).to exist

    get sales_coffee_conversion_path(conversion)
    costs = page.at_css("[data-conversion-costs]").text.squish
    expect(costs).to include("Secado", "L 25.00 por quintal de 100 lb brutas de lo que entró · 1,000.00 lb", "Caja", "L 250.00")

    expect(AccountBalance.new.for(account)).to eq(10_000 - 250)
    get finance_movements_path(from: "", to: "")
    expect(response.body).to include("Gasto de procesamiento", "Secado · proceso #{conversion.display_number}")

    # The next one starts as this site charged last time.
    get new_sales_coffee_conversion_cost_path(create(:coffee_conversion, processing_site: site))
    expect(page.at_css("#processing_cost_pricing_per_quintal")["checked"]).to be_present
    expect(page.at_css("#processing_cost_unit_price")["value"]).to eq("25.0")

    delete sales_coffee_conversion_cost_path(conversion, cost)
    expect(ProcessingCost.count).to eq(0)
  end

  it "keeps a cost without account for Consolidación" do
    create(:processing_cost, coffee_conversion: conversion, amount: 80)
    get finance_consolidation_path
    expect(response.body).to include("Gasto de procesamiento")
  end

  it "says what is missing, in Spanish" do
    post sales_coffee_conversion_costs_path(conversion), params: { processing_cost: { concept: "other", pricing: "per_pound", paid_on: "", payment_method: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Detalle es obligatorio cuando el concepto es «Otro»", "Precio (L) no es un número")
  end

  it "lets only who creates in Comercialización register one" do
    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true) }
    sign_in reader
    post sales_coffee_conversion_costs_path(conversion), params: { processing_cost: { concept: "fuel", pricing: "total", amount: "10", paid_on: Time.zone.today, payment_method: "cash" } }
    expect(ProcessingCost.count).to eq(0)
  end
end
