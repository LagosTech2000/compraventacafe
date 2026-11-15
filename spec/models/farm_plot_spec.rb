require "rails_helper"

# Plots of a farm and coffee varieties (Fernando, 2026-11-15: «lote es una
# parcela de la finca»; the variety, by farm and by plot).
RSpec.describe FarmPlot do
  let(:producer) { create(:producer) }
  let(:farm) { create(:farm, producer:) }
  let(:lempira) { CoffeeVariety.create!(name: "Lempira") }

  it "keeps its land and varieties, with a name unique within its farm" do
    plot = farm.plots.create!(name: "Lote 1", area_value: 1.5, area_unit: "manzana", variety_ids: [ "", lempira.id.to_s ])
    expect(plot).to have_attributes(variety_ids: [ lempira.id ], variety_names: [ "Lempira" ])
    expect(farm.plots.build(name: " lote  1 ")).not_to be_valid
    expect(create(:farm).plots.build(name: "Lote 1")).to be_valid
    expect(farm.plots.build(name: "Lote 2", variety_ids: [ 0 ])).not_to be_valid
  end

  it "goes on a purchase only with its own farm, and leaves with the farm" do
    plot = farm.plots.create!(name: "Lote 1")
    other = create(:farm, producer:).plots.create!(name: "Lote 1")
    purchase = create(:purchase, producer:, farm:, farm_plot: plot)
    expect(purchase.farm_plot).to eq(plot)

    purchase.farm_plot = other
    expect(purchase).not_to be_valid
    expect(purchase.errors[:farm_plot]).to include("no es una parcela de esa finca")

    purchase.farm = nil
    purchase.valid?
    expect(purchase.farm_plot).to be_nil
  end

  it "is not removed from its farm while a purchase names it" do
    plot = farm.plots.create!(name: "Lote 1")
    create(:purchase, producer:, farm:, farm_plot: plot)
    expect(farm.update(plots_attributes: [ { id: plot.id, _destroy: "1" } ])).to be(false)
    expect(farm.errors.full_messages.join).to include("«Lote 1» tiene compras")
  end

  it "moves with the farm when two people are merged" do
    other = create(:producer)
    kept = create(:farm, producer:, name: "El Paraíso", variety_ids: [ lempira.id ])
    joined = create(:farm, producer: other, name: "El Paraíso")
    twin = kept.plots.create!(name: "Lote 1")
    same = joined.plots.create!(name: "Lote 1")
    moved = joined.plots.create!(name: "Lote 2")
    purchase = create(:purchase, producer: other, farm: joined, farm_plot: same)

    expect(PersonMerge.new(primary: producer.person, secondary: other.person).save).to be(true)
    expect(kept.plots.reload.map(&:name)).to eq([ "Lote 1", "Lote 2" ])
    expect(moved.reload.farm).to eq(kept)
    expect(purchase.reload).to have_attributes(farm: kept, farm_plot: twin)
  end
end
