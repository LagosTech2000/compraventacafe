require "rails_helper"

# Reports' figures, charts and counts come from the cache while the data did
# not change (Report#cached, DataVersion; Fernando, 2026-10-18).
RSpec.describe "Report cache" do
  let(:user) { create(:user, :admin) }

  def run(**params) = PurchasesReport.new({ period: "this_month", **params }, user:)

  def queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  before { create(:purchase, purchased_at: Time.current) }

  it "reads the figures, charts and count again without asking the database" do
    first = run
    first_kpis = first.kpis
    first_charts = first.charts
    first.total_count

    report = run
    expect(queries { report.kpis; report.charts; report.total_count }).to eq(0)
    expect(report.kpis).to eq(first_kpis)
    expect(report.charts).to eq(first_charts)
  end

  it "shares the copy between sorts, but not between filters" do
    run.kpis

    expect(queries { run(sort: "total", dir: "asc").kpis }).to eq(0)
    expect(queries { run(coffee_state: "cherry").kpis }).to be > 0
  end

  it "counts again once the data changes" do
    expect(run.total_count).to eq(1)

    create(:purchase, purchased_at: Time.current)

    expect(run.total_count).to eq(2)
  end

  it "keeps apart users who see different modules" do
    run.kpis
    other = create(:user).tap { |u| %w[reports trading].each { |key| create(:permission, user: u, module_key: key, can_read: true) } }.reload

    expect(queries { PurchasesReport.new({ period: "this_month" }, user: other).kpis }).to be > 0
  end
end
