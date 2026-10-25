require "rails_helper"

RSpec.describe LoanBalance do
  let(:start) { Date.new(2026, 1, 1) }
  let(:loan) { create(:loan, cash_amount: 10_000, monthly_interest_rate: 3, disbursed_on: start, due_on: start + 120) }

  it "runs interest daily on the principal: principal × monthly rate × days / 30" do
    balance = described_class.new(loan, as_of: start + 45)

    expect(balance.interest_owed).to eq(450) # 10,000 × 3 % × 45/30
    expect(balance.total_owed).to eq(10_450)
  end

  it "applies a payment to interest first, then principal, and charges later interest on the new principal" do
    payment = create(:loan_payment, loan:, paid_on: start + 30, amount: 5_000)

    expect([ payment.interest_amount, payment.principal_amount ]).to eq([ 300, 4_700 ])
    later = described_class.new(loan, as_of: start + 60)
    expect(later.principal_owed).to eq(5_300)
    expect(later.interest_owed).to eq(159) # 5,300 × 3 %
  end

  it "carries interest a small payment did not cover" do
    create(:loan_payment, loan:, paid_on: start + 30, amount: 100)
    balance = described_class.new(loan, as_of: start + 30)

    expect(balance.interest_owed).to eq(200)
    expect(balance.principal_owed).to eq(10_000)
  end

  it "keeps charging the same rate after the due date" do
    expect(described_class.new(loan, as_of: start + 150).interest_owed).to eq(1_500)
  end

  it "charges nothing at a 0 % rate" do
    loan.update!(monthly_interest_rate: 0)
    expect(described_class.new(loan, as_of: start + 90).total_owed).to eq(10_000)
  end

  describe "a loan of the intermediary type: its first 10 days without interest" do
    let(:loan) { create(:loan, interest_grace: true, cash_amount: 10_000, monthly_interest_rate: 3, disbursed_on: start, due_on: start + 120) }

    it "charges nothing up to day 10 and from day 11 as usual" do
      expect(described_class.new(loan, as_of: start + 10).interest_owed).to eq(0)
      expect(described_class.new(loan, as_of: start + 11).interest_owed).to eq(10) # 1 day
      expect(described_class.new(loan, as_of: start + 45).interest_owed).to eq(350) # 35 days
      expect(loan.interest_starts_on).to eq(start + 10)
    end

    it "lets a payment within the 10 days go all to the principal" do
      payment = create(:loan_payment, loan:, paid_on: start + 5, amount: 4_000)
      expect([ payment.interest_amount, payment.principal_amount ]).to eq([ 0, 4_000 ])
      expect(described_class.new(loan, as_of: start + 40).interest_owed).to eq(180) # 6,000 × 3 % × 30/30
    end

    it "is for anyone, not only intermediaries" do
      expect(create(:loan, person: create(:person, :client), interest_grace: true)).to be_persisted
    end
  end
end
