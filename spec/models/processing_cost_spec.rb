require "rails_helper"

# What processing cost (client, 2026-10-26): a total, or a price per pound
# or per quintal on a weight of the process; it adds to the coffee's value.
RSpec.describe ProcessingCost do
  let(:conversion) { create(:coffee_conversion, input_gross_weight: 1_000, weighed_at: 2.hours.ago) }

  def cost(**attributes) = build(:processing_cost, coffee_conversion: conversion, **attributes)

  it "charges an agreed total as typed" do
    expect(cost(amount: 750).tap(&:save!)).to have_attributes(amount: 750, base_pounds: nil, quantity: nil, unit_price: nil)
  end

  it "charges per pound or per quintal on the weight chosen, and keeps the basis" do
    per_pound = cost(pricing: "per_pound", weight_side: "input", weight_kind: "gross", unit_price: 0.5).tap(&:save!)
    expect(per_pound).to have_attributes(base_pounds: 1_000, quantity: 1_000, amount: 500)

    per_quintal = cost(pricing: "per_quintal", weight_side: "input", weight_kind: "gross", quintal_pounds: 125, unit_price: 20).tap(&:save!)
    expect(per_quintal).to have_attributes(quantity: 8, amount: 160)
  end

  it "charges on what came out only once the process has its result" do
    expect(cost(pricing: "per_pound", weight_side: "output", weight_kind: "gross", unit_price: 1)).not_to be_valid

    finished = create(:coffee_conversion, :finished, weighed_at: 3.hours.ago) # 400 lb out
    on_output = build(:processing_cost, coffee_conversion: finished, pricing: "per_quintal", weight_side: "output", weight_kind: "gross",
                                        quintal_pounds: 100, unit_price: 50)
    expect(on_output.tap(&:save!).amount).to eq(200)
    expect { finished.reopen! }.to raise_error(ActiveRecord::RecordInvalid, /quítalos primero/)
  end

  it "asks a detail for «Otro» and does not let a process with costs be voided" do
    expect(cost(concept: "other")).not_to be_valid
    cost.save!
    expect { conversion.void!(create(:user)) }.to raise_error(ActiveRecord::RecordInvalid, /gastos registrados/)
  end

  it "adds to the value of the coffee that came out" do
    create(:purchase, coffee_state: "cherry", gross_weight: 2_000, purchased_at: 1.day.ago)
    finished = create(:coffee_conversion, :finished, weighed_at: 3.hours.ago)
    create(:processing_cost, coffee_conversion: finished, amount: 300)

    lot = CoffeeLots.new.lots(coffee_state: "wet_parchment").sole
    taken = CoffeeLots.new.portions_for(finished)
    expect(lot.costs).to eq(taken.sum(&:costs) + 300)
    expect(lot.purchase_value).to eq(taken.sum(&:purchase_value))
  end
end
