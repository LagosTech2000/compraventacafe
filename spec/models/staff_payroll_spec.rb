require "rails_helper"

# Planilla interna (Fernando, 2026-10-24): a fixed salary per period of the
# role, overtime at the role's hour rate, goals with a bonus marked when
# paying, a free bonus, and advances taken off in full from their period.
RSpec.describe "Planilla interna" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:account) { create(:money_account, opening_balance: 50_000) }
  let(:role) { create(:staff_role, salary: 6_000, pay_frequency: "biweekly", overtime_hour_rate: 50) }
  let(:member) { create(:staff_member, role:, starts_on: Date.new(2026, 10, 1)) }

  around { |example| travel_to(Date.new(2026, 10, 20)) { example.run } }

  # Every day of the period worked (the salary is monthly and paid by days).
  def attend(someone, period)
    period.dates.each { |date| someone.attendances.find_or_create_by!(worked_on: date) { it.day_fraction = 1 } }
    someone.reload
  end

  def pay(period = member.reload.period_to_pay, **options)
    attend(member, period) if period && member.paid_period?(period) == false && period.ends_on <= Time.zone.today
    issuer = StaffPaymentIssuer.new(member: member.reload, period:, user:, payment_method: "cash", money_account_id: account.id,
                                    paid_on: Time.zone.today, **options)
    [ issuer.call, issuer ]
  end

  it "has the periods of its role's frequency, paid in order" do
    expect(member.periods.map { [ it.starts_on.day, it.ends_on.day ] }).to eq([ [ 1, 15 ], [ 16, 31 ] ])
    expect(member.period_to_pay).to eq(PayPeriod.new(Date.new(2026, 10, 1), Date.new(2026, 10, 15)))
    expect(member.due_periods.size).to eq(1)

    later = member.periods.last
    expect(pay(later).first).to be(false)
  end

  it "pays salary + overtime + goals met + a free bonus − the advances of the period" do
    met = create(:staff_goal, member:, period_starts_on: Date.new(2026, 10, 1), bonus_amount: 300)
    missed = create(:staff_goal, member:, period_starts_on: Date.new(2026, 10, 1), bonus_amount: 200, description: "Otra")
    advance = create(:staff_advance, member:, given_on: Date.new(2026, 10, 10), amount: 1_000, money_account: account)
    later_advance = create(:staff_advance, member:, given_on: Date.new(2026, 10, 18), amount: 400, money_account: account)

    ok, issuer = pay(overtime_hours: "4", met_goal_ids: [ met.id.to_s ], extra_bonus: "150", extra_bonus_reason: "Buen trabajo")
    expect(ok).to be(true)
    payment = issuer.payment
    # 6,000 a month ÷ 30 × 15 days = 3,000 + 4 × 50 + 300 + 150 = 3,650; − 1,000 = 2,650
    expect(payment).to have_attributes(days_worked: 15, salary: 3_000, overtime_amount: 200, goals_bonus: 300, extra_bonus: 150,
                                       gross_total: 3_650, advances_total: 1_000, net_total: 2_650)
    expect([ met.reload.met, missed.reload.met ]).to eq([ true, false ])
    expect(advance.reload.payment).to eq(payment)
    expect(later_advance.reload.payment).to be_nil

    # The account lost the advances when given and the net when paid.
    expect(AccountBalance.new.for(account)).to eq(50_000 - 1_000 - 400 - 2_650)
    sources = MoneyMovements.new.all.map(&:source)
    expect(sources.tally).to include("staff_payments" => 1, "staff_advances" => 2)
  end

  it "asks a reason for a free bonus, a rate for overtime, and never pays below zero" do
    expect(pay(extra_bonus: "100").first).to be(false)
    role.update!(overtime_hour_rate: nil)
    expect(pay(overtime_hours: "2").first).to be(false)

    role.update!(overtime_hour_rate: 50)
    create(:staff_advance, member:, given_on: Date.new(2026, 10, 2), amount: 7_000, money_account: account)
    ok, issuer = pay
    expect(ok).to be(false)
    expect(issuer.payment.errors[:base]).to include(a_string_including("Los anticipos pasan de lo ganado"))
  end

  it "keeps advances and goals off paid periods, and frees them when the last payment goes" do
    goal = create(:staff_goal, member:, period_starts_on: Date.new(2026, 10, 1))
    advance = create(:staff_advance, member:, given_on: Date.new(2026, 10, 5), money_account: account)
    _, issuer = pay(met_goal_ids: [ goal.id ])
    payment = issuer.payment

    expect(build(:staff_advance, member: member.reload, given_on: Date.new(2026, 10, 3), money_account: account)).not_to be_valid
    expect(build(:staff_goal, member:, period_starts_on: Date.new(2026, 10, 1))).not_to be_valid
    expect(advance.reload.destroy).to be(false)
    expect(goal.reload.destroy).to be(false)

    payment.destroy!
    expect(advance.reload.payment).to be_nil
    expect(goal.reload).to have_attributes(met: nil, payment: nil)
  end

  it "only removes the latest payment, and keeps what each payment paid when the role changes" do
    travel 13.days # 2026-11-02
    first = pay.last.payment
    role.update!(salary: 7_000)
    second = pay.last.payment
    expect([ first.reload.salary, second.salary ]).to eq([ 3_000, 3_500 ]) # 15 days of 6,000, then of 7,000 a month
    expect(first.destroy).to be(false)
    expect(second.destroy).to be_truthy
  end

  it "lets a role wait without salary nor frequency (both or none), with nothing to pay meanwhile" do
    waiting = create(:staff_role, name: "Cargador", salary: nil, pay_frequency: nil)
    expect(waiting).not_to be_priced
    expect(build(:staff_role, salary: 5_000, pay_frequency: nil)).not_to be_valid
    expect(build(:staff_role, salary: nil, pay_frequency: "weekly")).not_to be_valid

    loader = create(:staff_member, role: waiting, starts_on: Date.new(2026, 10, 1))
    expect([ loader.periods, loader.period_to_pay, loader.due_periods ]).to eq([ [], nil, [] ])
    expect(StaffOverview.new.due).to be_empty

    waiting.update!(salary: 4_000, pay_frequency: "biweekly")
    expect(loader.reload.period_to_pay.starts_on).to eq(Date.new(2026, 10, 1))
  end

  it "pays an employee's own salary over the role's, with the role's frequency and overtime rate" do
    driver = create(:staff_member, role:, starts_on: Date.new(2026, 10, 1), salary_override: 7_000)
    other = create(:staff_member, role:, starts_on: Date.new(2026, 10, 1))
    expect([ driver.salary, other.salary ]).to eq([ 7_000, 6_000 ])
    expect(driver.period_to_pay).to eq(other.period_to_pay)

    attend(driver, driver.period_to_pay)
    issuer = StaffPaymentIssuer.new(member: driver, period: driver.period_to_pay, user:, overtime_hours: "2", payment_method: "cash",
                                    money_account_id: account.id)
    expect(issuer.call).to be(true)
    expect(issuer.payment).to have_attributes(salary: 3_500, overtime_amount: 100, net_total: 3_600)
    expect(build(:staff_member, salary_override: 0)).not_to be_valid
  end

  it "takes a collaborator once, in an active role" do
    expect(build(:staff_member, person: create(:person, :client))).not_to be_valid
    expect(build(:staff_member, person: member.person)).not_to be_valid
    expect(build(:staff_member, role: create(:staff_role, active: false))).not_to be_valid
  end
end
