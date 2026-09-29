require "rails_helper"

RSpec.describe LoanBalance do
  let(:start) { Date.new(2026, 1, 1) }
  let(:loan) { create(:loan, principal: 10_000, monthly_interest_rate: 3, disbursed_on: start, due_on: start + 120) }

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
end
