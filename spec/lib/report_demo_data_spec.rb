require "rails_helper"

RSpec.describe ReportDemoData do
  it "lives a few weeks of the harvest through the models, with something for every report" do
    admin = create(:user, :admin)
    data = described_class.new(admin, from: Date.new(2025, 12, 1), to: Date.new(2025, 12, 20)).load

    expect(described_class).to be_loaded
    expect(data.counts).to include(:purchases, :invoices, :attendances, :harvest_entries, :payroll_payments)
    expect(data.counts[:payroll_payment_errors]).to eq(0)
    expect(Purchase.active.count).to eq(data.counts[:purchases] - Purchase.voided.count)
    expect(Payroll.where(kind: "harvest").flat_map { |payroll| payroll.periods_to_pay(Date.new(2025, 12, 20)) }).to be_empty
    Report.catalog.each do |report|
      expect(report.new({ period: "all" }, user: admin).total_count).to be_positive, report.key
    end
  end
end
