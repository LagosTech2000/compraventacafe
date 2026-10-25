require "rails_helper"

# The payroll sheet works like the client's Excel (Fernando, 2026-10-25):
# monthly salary ÷ 30 × days worked − advances; a fortnight worked whole
# counts 15 days.
RSpec.describe StaffSheet do
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { create(:money_account) }
  let(:driver) { create(:staff_role, name: "Chofer", salary: 15_000, pay_frequency: "biweekly") }

  around { |example| travel_to(Date.new(2026, 10, 20)) { example.run } }

  def employee(salary:, starts_on: Date.new(2026, 10, 1), role: driver)
    create(:staff_member, role:, salary_override: salary, starts_on:)
  end

  def work(member, days, fraction: 1)
    days.each { |day| member.attendances.create!(worked_on: Date.new(2026, 10, day), day_fraction: fraction) }
    member.reload
  end

  def advance(member, amount, day: 3)
    create(:staff_advance, member:, amount:, given_on: Date.new(2026, 10, day), money_account: account)
  end

  def row(member, sheet = described_class.new(month: "2026-10", half: 1)) = sheet.rows.find { it.member == member }

  it "matches the Excel's first fortnight of October" do
    alejandro = work(employee(salary: 15_000), 3..14) # 12 days
    advance(alejandro, 1_500)
    santos = work(employee(salary: 13_000), [ *1..6, *8..15 ]) # 14 days
    advance(santos, 1_000)
    reyna = work(employee(salary: 6_000), [ 3, 4, 5, 6, 9, 10, 11 ]) # 7 days
    advance(reyna, 1_000)
    emanuel = work(employee(salary: 10_000), 1..15)

    expect([ row(alejandro).days, row(alejandro).earned, row(alejandro).total ]).to eq([ 12, 6_000, 4_500 ])
    expect([ row(santos).days, row(santos).total ]).to eq([ 14, BigDecimal("5066.67") ])
    expect(row(reyna).total).to eq(400)
    expect([ row(emanuel).days, row(emanuel).total ]).to eq([ 15, 5_000 ])
  end

  it "counts 15 for a fortnight worked whole of 16 days, at most 15 otherwise, and halves" do
    whole = work(employee(salary: 15_000), 16..31)
    one_off = work(employee(salary: 15_000), 16..30)
    halves = work(employee(salary: 15_000), 16..19, fraction: 0.5)
    second = described_class.new(month: "2026-10", half: 2)
    expect(row(whole, second).days).to eq(15)
    expect(row(one_off, second).days).to eq(15) # 15 of 16 marked: never more than 15
    expect(row(halves, second).days).to eq(2)

    starter = work(employee(salary: 15_000, starts_on: Date.new(2026, 10, 5)), 5..15)
    expect(row(starter).days).to eq(11) # started on the 5th: not the whole fortnight
  end

  it "pays the period by the days worked, minus its advances" do
    member = work(employee(salary: 15_000), 3..14)
    advance(member, 1_500)
    issuer = StaffPaymentIssuer.new(member:, period: member.period_to_pay, user: create(:user), payment_method: "cash", money_account_id: account.id)
    expect(issuer.call).to be(true)
    expect(issuer.payment).to have_attributes(monthly_salary: 15_000, days_worked: 12, salary: 6_000, net_total: 4_500)
    expect(member.attendances.build(worked_on: Date.new(2026, 10, 15), day_fraction: 1)).not_to be_valid # a paid period stays
  end

  it "adds up the month and what each month was paid, and estimates the current one" do
    member = work(employee(salary: 15_000), 1..15)
    StaffPaymentIssuer.new(member:, period: member.period_to_pay, user: create(:user), payment_method: "cash", money_account_id: account.id).call
    work(member, 16..20)

    month = described_class.new(view: "month", month: "2026-10")
    expect(row(member, month)).to have_attributes(fortnights: [ 15, 5 ], days: 20, earned: 10_000, paid: 7_500)

    history = described_class.new(view: "history")
    line = history.history_rows.find { it.member == member }
    expect(history.past_months.first).to eq(Date.new(2026, 9, 1))
    # 2nd fortnight: 5 days so far, 11 left → 15 (whole if no day is missed)
    expect([ line.paid_now, line.pending_now, line.month_total ]).to eq([ 7_500, 7_500, 15_000 ])
  end

  it "only pays together the due periods of the fortnight with no goal to review" do
    ready = work(employee(salary: 15_000), 1..15)
    with_goal = work(employee(salary: 15_000), 1..15)
    create(:staff_goal, member: with_goal, period_starts_on: Date.new(2026, 10, 1))
    sheet = described_class.new(month: "2026-10", half: 1)
    expect(sheet.payable_rows.map(&:member)).to eq([ ready ])
    expect(described_class.new(month: "2026-10", half: 2).payable_rows).to be_empty
  end
end
