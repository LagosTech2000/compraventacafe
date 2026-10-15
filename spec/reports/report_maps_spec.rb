require "rails_helper"

# Map charts in Reportería (Fernando, 2026-10-13): the filtered records,
# grouped by the person or farm they belong to that has a point on the map,
# sized by the report's figure; those without a point are counted apart.
RSpec.describe "Report maps" do
  let(:user) { create(:user, :admin) }

  def run(report_class, **params) = report_class.new(params, user:)
  def map_of(report) = report.charts.find { |chart| chart.type == :map }

  it "puts each purchase at its farm, or at its producer when the farm has no point" do
    ana = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya", latitude: 14.1, longitude: -86.9))
    beto = create(:producer, person: create(:person, first_names: "Beto", last_names: "Mejía"))
    cerro = create(:farm, producer: beto, name: "El Cerro", latitude: 14.2, longitude: -86.8)
    create(:purchase, producer: ana, gross_weight: 1000)
    create(:purchase, producer: beto, farm: cerro, gross_weight: 3000)
    create(:purchase, producer: beto, gross_weight: 500) # no farm, Beto has no point

    map = map_of(run(PurchasesReport, period: "all"))
    expect(map.labels).to eq([ "El Cerro · Beto Mejía", "Ana Zelaya" ]) # the most first
    expect(map.options[:points].map { [ it[:latitude], it[:longitude], it[:link_id] ] })
      .to eq([ [ 14.2, -86.8, beto.id ], [ 14.1, -86.9, ana.id ] ])
    expect(map.datasets.first).to include(format: :quintals)
    expect(map.datasets.first[:data].first).to be > map.datasets.first[:data].last
    expect(map.options).to include(link: :trading_producer_path, missing: 1)
  end

  it "shows the producers where they are, with what they sold in the period" do
    ana = create(:producer, person: create(:person, latitude: 14.1, longitude: -86.9))
    create(:producer, person: create(:person, latitude: 14.15, longitude: -86.85)) # sold nothing: a small point
    create(:producer)
    create(:purchase, producer: ana)

    map = map_of(run(ProducersReport, period: "all"))
    expect(map.options[:points].size).to eq(2)
    expect(map.datasets.first[:data]).to eq([ (ana.purchases.sum(:net_weight) / 125).round(2).to_f, 0.0 ])
    expect(map.options[:missing]).to eq(1)
  end

  it "shows the payrolls, the harvest and the expenses at their farms" do
    farm = create(:farm, latitude: 14.05, longitude: -86.95)
    payroll = create(:payroll, farm:)
    create(:payroll_expense, payroll:, amount: 250)

    map = map_of(run(PayrollExpensesReport, period: "all"))
    expect(map.labels).to eq([ farm.name ])
    expect(map.datasets.first[:data]).to eq([ 250.0 ])
    expect(map.options).to include(link: :farms_farm_path, missing: 0)
    expect(map.options[:points].first[:link_id]).to eq(farm.id)
  end

  it "has a map in every report about people or farms" do
    keys = Report.catalog.select { |report| report.new({}, user:).charts.any? { it.type == :map } }.map(&:key)
    expect(keys).to match_array(%w[purchases producers invoices loans payroll_payments harvest payroll_expenses farms people])
  end
end
