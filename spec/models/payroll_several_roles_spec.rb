require "rails_helper"

# The same person working a daily payroll in several roles (Fernando,
# 2026-10-17: driver 3 days, laborer 2 days), never the same day; paid with
# one line per role and their loans taken once, from the total.
RSpec.describe "A person in several roles of a payroll" do
  let(:user) { create(:user, :admin) }
  let(:payroll) { create(:payroll, kind: "daily", pay_frequency: "weekly", starts_on: Date.new(2026, 10, 4)) } # a Sunday
  let(:driver) { create(:payroll_role, payroll:, name: "Chofer", daily_wage: 400) }
  let(:laborer) { create(:payroll_role, payroll:, name: "Jornalero", daily_wage: 300) }
  let(:person) { create(:person, :collaborator, first_names: "Ana", last_names: "Zelaya") }
  let!(:as_driver) { create(:payroll_member, payroll:, person:, role: driver) }
  let!(:as_laborer) { create(:payroll_member, payroll:, person:, role: laborer) }
  let(:period) { payroll.periods.first }
  let(:days) { period.dates.to_a }

  describe "members" do
    it "takes the same person once per role" do
      expect(as_laborer).to be_valid
      duplicate = build(:payroll_member, payroll:, person:, role: driver)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:person_id].join).to include("con ese rol")
    end

    it "takes them once with a wage of their own and no role" do
      create(:payroll_member, payroll:, person:, role: nil, daily_wage_override: 350)
      expect(build(:payroll_member, payroll:, person:, role: nil, daily_wage_override: 360)).not_to be_valid
    end

    it "still takes each person once in harvest and task payrolls" do
      %w[harvest task].each do |kind|
        other = create(:payroll, kind:, can_price: (kind == "harvest" ? 50 : nil), starts_on: Date.new(2026, 10, 4))
        create(:payroll_member, payroll: other, person:)
        expect(build(:payroll_member, payroll: other, person:)).not_to be_valid
      end
    end

    it "keeps a payroll daily while a person is in it twice" do
      payroll.kind = "task"
      expect(payroll).not_to be_valid
      expect(payroll.errors[:kind].join).to include("varios roles")
    end

    it "labels each membership with its role" do
      expect(as_driver.label).to eq("Ana Zelaya · Chofer")
    end
  end

  describe "attendance" do
    it "puts each day in one role only" do
      PayrollAttendance.create!(member: as_driver, worked_on: days[0], day_fraction: 1)
      taken = PayrollAttendance.new(member: as_laborer, worked_on: days[0], day_fraction: 0.5)
      expect(taken).not_to be_valid
      expect(taken.errors[:worked_on].join).to include("como Chofer")
      expect(PayrollAttendance.new(member: as_laborer, worked_on: days[1], day_fraction: 1)).to be_valid
    end

    it "moves a day from one role to the other in a single save, and refuses a day in both" do
      sheet = PayrollTimesheet.new(payroll, period)
      expect(sheet.update({ as_driver.id.to_s => { days[0].iso8601 => "1" } })).to be(true)

      sheet = PayrollTimesheet.new(payroll, period)
      moved = { as_laborer.id.to_s => { days[0].iso8601 => "1" }, as_driver.id.to_s => { days[0].iso8601 => "" } }
      expect(sheet.update(moved)).to be(true)
      expect(as_laborer.attendances.pluck(:worked_on)).to eq([ days[0] ])
      expect(as_driver.attendances).to be_empty

      sheet = PayrollTimesheet.new(payroll, period)
      expect(sheet.update({ as_driver.id.to_s => { days[0].iso8601 => "1" } })).to be(false)
      expect(sheet.errors.full_messages.join).to include("Ana Zelaya · Chofer", "como Jornalero")
    end
  end

  describe "paying the period" do
    let(:loan) { create(:loan, person:, cash_amount: 5_000, monthly_interest_rate: 0, disbursed_on: days[0] - 30) }

    before do
      days.first(3).each { PayrollAttendance.create!(member: as_driver, worked_on: it, day_fraction: 1) }   # 1,200
      days[3, 2].each { PayrollAttendance.create!(member: as_laborer, worked_on: it, day_fraction: 1) }    # 600
    end

    def issuer(amounts = {})
      PayrollPaymentIssuer.new(payroll:, period:, user:, paid_on: period.ends_on, loan_amounts: amounts, with_loans: true)
    end

    it "groups the person's lines and takes their loans once, from the total" do
      expect(issuer.person_lines.map { |group| group.map(&:gross_amount) }).to eq([ [ 1_200, 600 ] ])

      paying = issuer(loan.id => "1500")
      expect(paying.save).to be(true), paying.errors.full_messages.join
      lines = paying.payment.lines.sort_by(&:gross_amount).reverse
      expect(lines.map(&:loans_amount)).to eq([ 1_200, 300 ])
      expect(lines.map(&:net_amount)).to eq([ 0, 300 ])
      expect(paying.payment).to have_attributes(gross_total: 1_800, loans_total: 1_500, net_total: 300)
      expect(loan.payments.sum(:amount)).to eq(1_500)
      expect(loan.payments.last.payroll_payment_line).to eq(lines.first)
    end

    it "refuses to take more than the person earns in all their roles" do
      paying = issuer(loan.id => "1800.01")
      expect(paying.save).to be(false)
      expect(paying.errors.full_messages.join).to include("Ana Zelaya", "L 1,800.00")
    end
  end
end
