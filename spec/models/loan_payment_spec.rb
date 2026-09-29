require "rails_helper"

RSpec.describe LoanPayment do
  let(:start) { Date.new(2026, 1, 1) }
  let(:loan) { create(:loan, principal: 1_000, monthly_interest_rate: 3, disbursed_on: start, due_on: start + 60) }

  it "marks the loan paid off when a payment covers everything" do
    create(:loan_payment, loan:, paid_on: start + 30, amount: 1_030)

    expect(loan.reload.paid_off_on).to eq(start + 30)
    expect(loan).to be_paid_on_time
  end

  it "refuses more than what is owed on that date" do
    payment = build(:loan_payment, loan:, paid_on: start + 30, amount: 1_030.01)

    expect(payment).not_to be_valid
    expect(payment.errors[:amount].first).to include("L 1,030.00")
  end

  it "refuses a date before the loan or before the last payment" do
    create(:loan_payment, loan:, paid_on: start + 20, amount: 100)

    expect(build(:loan_payment, loan:, paid_on: start + 10)).not_to be_valid
    expect(build(:loan_payment, loan:, paid_on: start - 1)).not_to be_valid
    expect(build(:loan_payment, loan:, paid_on: start + 20, amount: 10)).to be_valid
  end

  it "reopens the loan when its last payment is removed" do
    payment = create(:loan_payment, loan:, paid_on: start + 30, amount: 1_030)
    payment.destroy!

    expect(loan.reload.paid_off_on).to be_nil
  end

  it "knows which payment is the latest" do
    first = create(:loan_payment, loan:, paid_on: start + 10, amount: 100)
    last = create(:loan_payment, loan:, paid_on: start + 20, amount: 100)

    expect([ first.latest?, last.latest? ]).to eq([ false, true ])
  end
end
