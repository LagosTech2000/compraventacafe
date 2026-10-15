require "rails_helper"

# Farm yield (Fernando, 2026-10-14): coffee bought from each farm, cans
# picked, what it cost, and per manzana or hectare with its land written.
RSpec.describe FarmsReport do
  let(:user) { create(:user, :admin) }
  let(:today) { Time.zone.today }

  def run(**params) = described_class.new(params, user:)
  def kpi(report, key) = report.kpis.find { |figure| figure.key == key }

  it "puts each farm's coffee, cans and cost side by side, per manzana and hectare when it has its land" do
    producer = create(:producer)
    farm = create(:farm, producer:, name: "El Cerro", area_value: 2, area_unit: "manzana")
    plain = create(:farm, producer:, name: "La Loma")
    2.times { create(:purchase, producer:, farm:, gross_weight: 1000) }
    create(:purchase, producer:, farm: plain, gross_weight: 500)
    create(:purchase, producer:, farm:, voided_at: Time.current, voided_by: user)
    create(:purchase, producer:, farm:, purchased_at: 2.years.ago)

    harvest = create(:payroll, farm:, kind: "harvest", can_price: 25, starts_on: today - 3)
    picker = create(:payroll_member, payroll: harvest)
    HarvestEntry.create!(member: picker, worked_on: today, cans: 12)
    create(:payroll_expense, payroll: harvest, amount: 700, spent_on: today)

    report = run(period: "this_season")
    rows = report.page.first.index_by(&:name)
    expect(rows.keys).to contain_exactly("El Cerro", "La Loma")

    cerro = rows.fetch("El Cerro")
    columns = report.table_columns.index_by(&:key)
    value = ->(key, row) { columns.fetch(key).value.call(row) }
    net = Purchase.active.where(farm:, season_year: Season.current.year).sum(:net_weight)
    expect(value.(:quintals, cerro)).to eq(net / 125)
    expect(value.(:cans, cerro)).to eq(12)
    expect(value.(:cost, cerro)).to eq(700)
    expect(value.(:balance, cerro)).to eq(Purchase.active.where(farm:, season_year: Season.current.year).sum(:total) - 700)
    expect(value.(:manzanas, cerro)).to eq(2)
    expect(value.(:hectares, cerro)).to eq(BigDecimal("1.397792"))
    expect(value.(:quintals_per_manzana, cerro)).to eq(net / 125 / 2)
    expect(value.(:quintals_per_manzana, rows.fetch("La Loma"))).to be_nil

    # Only farms with land count for QQ per manzana.
    expect(kpi(report, :quintals_per_manzana).value.round(6)).to eq((net / 125 / 2).round(6))
    expect(kpi(report, :cans).value).to eq(12)
    expect(kpi(report, :cost).value).to eq(700)
  end

  it "filters by owner and leaves out farms with nothing in the period unless asked" do
    create(:farm, name: "Del negocio")
    create(:farm, producer: create(:producer), name: "De productor")
    expect(run(period: "this_season").total_count).to eq(0)
    expect(run(period: "this_season", activity: "").total_count).to eq(2)
    expect(run(period: "this_season", activity: "", owner: "business").page.first.map(&:name)).to eq([ "Del negocio" ])
    expect(run(period: "this_season", activity: "", owner: "producers").page.first.map(&:name)).to eq([ "De productor" ])
  end

  it "groups by owner, sorts by QQ per manzana, and needs Fincas and Compra de café" do
    producer = create(:producer)
    small = create(:farm, producer:, name: "Pequeña", area_value: 1, area_unit: "manzana")
    big = create(:farm, producer:, name: "Grande", area_value: 10, area_unit: "hectare")
    create(:purchase, producer:, farm: small, gross_weight: 1000)
    create(:purchase, producer:, farm: big, gross_weight: 1000)

    expect(run(period: "this_season", sort: "quintals_per_manzana").page.first.map(&:name)).to eq([ "Pequeña", "Grande" ])
    rows = run(period: "this_season", group: "owner_kind").page.first
    expect(rows.map(&:label)).to eq([ "De productores" ])
    expect(described_class.module_keys).to contain_exactly("farms", "trading")
  end
end
