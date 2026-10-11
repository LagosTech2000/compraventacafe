require "rails_helper"

RSpec.describe DemoData do
  it "loads fictitious data, leaving today's purchases uninvoiced" do
    described_class.new(create(:user, :admin)).load
    expect(Producer.count).to eq(15)
    expect(Person.pluck(:last_names)).to all(start_with("Demo"))
    expect(Farm.pluck(:name)).to all(end_with("(demo)"))
    expect(Purchase.on(Time.zone.today).uninvoiced.count).to eq(Purchase.on(Time.zone.today).count)
    expect(Invoice.count).to be_positive
    expect(Loan.pluck(:paid_off_on).compact.size).to eq(2)
    expect(Loan.overdue.count).to eq(1)
    expect(Payroll.pluck(:kind)).to contain_exactly("daily", "harvest", "task")
    expect(PayrollPayment.sole.loans_total).to eq(500)
    expect(Payroll.find_by(kind: "daily").periods_to_pay).not_to be_empty
  end
end
