require "rails_helper"

# The sums behind the loans module's collection screens (Fernando, 2026-11-03).
RSpec.describe "Loan collection models" do
  let(:today) { Date.new(2026, 11, 4) } # a Wednesday

  def loan_due(days) = build(:loan, due_on: today + days)

  describe LoanAging do
    it "puts each loan in its tramo by how near or late its due date is" do
      aging = described_class.new(today:)
      expected = { 31 => "current", 30 => "due_soon", 0 => "due_soon", -1 => "late_30", -30 => "late_30", -31 => "late_60",
                   -60 => "late_60", -61 => "late_90", -90 => "late_90", -91 => "late_more" }
      expect(expected.keys.to_h { [ it, aging.bucket_for(loan_due(it)) ] }).to eq(expected)
    end

    it "links each tramo to the due dates it covers" do
      aging = described_class.new(today:)
      LoanAging::BUCKETS.each do |key|
        from, to = aging.due_range(key)
        [ from, to ].compact.each { expect(aging.bucket_for(build(:loan, due_on: it))).to eq(key) }
      end
    end
  end

  describe LoanCalendar do
    it "splits the late loans, this week from today, the next 12 weeks and later" do
      late = create(:loan, due_on: today - 1, disbursed_on: today - 30)
      this_week = create(:loan, due_on: today, disbursed_on: today - 30)
      next_week = create(:loan, due_on: today + 5, disbursed_on: today - 30)
      later = create(:loan, due_on: today + 200, disbursed_on: today - 30)

      buckets = LoanCalendar.new(today:).buckets
      expect(buckets.size).to eq(LoanCalendar::WEEKS + 2)
      expect(buckets.first.loans).to eq([ late ])
      expect(buckets.second.loans).to eq([ this_week ])
      expect(buckets.second.starts_on).to eq(today)
      expect(buckets.third.loans).to eq([ next_week ])
      expect(buckets.last.loans).to eq([ later ])
    end
  end

  describe LoanSimulation do
    it "goes month by month from the loan's date" do
      simulation = described_class.new(amount: 1_000, monthly_interest_rate: 3, disbursed_on: today, paid_on: today + 15)
      expect(simulation.result.interest).to eq(15)
      expect(simulation.by_month.map(&:total)).to eq([ 1_030, 1_060, 1_090, 1_120, 1_150, 1_180 ])
    end
  end

  describe Dashboard do
    it "counts as due soon from today to 7 days ahead" do
      user = create(:user, :admin)
      [ -1, 0, 7, 8 ].each { create(:loan, due_on: today + it, disbursed_on: today - 30) }
      expect(Dashboard.new(user, today:).due_soon_loans.map(&:due_on)).to eq([ today, today + 7 ])
    end
  end
end
