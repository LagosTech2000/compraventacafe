require "rails_helper"

# A lot takes shares of finished processes too (Fernando, 2026-11-16),
# mixed with invoices: never one in process, never past 100 % or the lot's
# limit; the process's result does not change while in a lot; a shipment
# with that lot takes that process's coffee from the stock.
RSpec.describe CoffeeBatchConversion do
  let(:user) { create(:user, :admin) }
  let(:conversion) { create(:coffee_conversion, :finished, from_state: "cherry", weighed_at: 2.days.ago) }
  let(:batch) { create(:coffee_batch, coffee_state: "wet_parchment", gross_limit: 1_000) }

  it "takes a percent of what came out, mixed with invoices, within 100 % and the lot's limit" do
    share = batch.batch_conversions.create!(coffee_conversion: conversion, percent: 50, created_by: user)
    expect(share).to have_attributes(gross_weight: conversion.output_gross_weight / 2, net_weight: (conversion.output_net_weight / 2).round(6))
    expect(batch.reload.gross_weight).to eq(share.gross_weight)

    other = create(:coffee_batch, coffee_state: "wet_parchment", gross_limit: 1_000)
    expect(other.batch_conversions.build(coffee_conversion: conversion, percent: 60, created_by: user)).not_to be_valid
    tight = create(:coffee_batch, coffee_state: "wet_parchment", gross_limit: 10)
    expect(tight.batch_conversions.build(coffee_conversion: conversion, percent: 10, created_by: user)).not_to be_valid
  end

  it "does not take a process in progress nor one of another coffee state" do
    running = create(:coffee_conversion, from_state: "cherry")
    expect(batch.batch_conversions.build(coffee_conversion: running, percent: 10, created_by: user)).not_to be_valid
    dry = create(:coffee_batch, coffee_state: "dry_parchment")
    expect(dry.batch_conversions.build(coffee_conversion: conversion, percent: 10, created_by: user)).not_to be_valid
  end

  it "keeps the process's result while in a lot, and a shipment with the lot takes its coffee" do
    batch.batch_conversions.create!(coffee_conversion: conversion, percent: 100, created_by: user)
    expect { conversion.reopen! }.to raise_error(ActiveRecord::RecordInvalid, /está en lotes/)

    shipment = create(:shipment, origin_gross_weight: conversion.output_gross_weight)
    batch.update!(shipment:)
    expect(CoffeeStock.new.row("wet_parchment").stock).to eq(0)
    expect(CoffeeLots.new.portions_for(shipment).map { it.lot.source }).to eq([ conversion ])
    expect(batch.totals.value).to be_positive
  end
end
