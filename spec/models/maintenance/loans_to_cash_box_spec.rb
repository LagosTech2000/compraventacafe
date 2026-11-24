require "rails_helper"

# loans:to_cash_box (Fernando, 2026-11-23): the loans' account goes away;
# what it had goes where the money moved, and nothing is left without an
# account in Movimientos or Consolidación.
RSpec.describe Maintenance::LoansToCashBox do
  let(:box) { create(:money_account, name: "Caja", default_for: %w[cash], opening_balance: 10_000, opening_on: Date.new(2026, 9, 30)) }
  let(:loans) { create(:money_account, name: "Préstamos", default_for: %w[loans], opening_balance: 0) }
  let(:producer) { create(:producer) }

  it "moves the loans and payments in money to the cash box, leaves the portfolio and the coffee without one, and is undone" do
    box
    old = create(:loan, person: producer.person, cash_amount: 5_000, monthly_interest_rate: 0, disbursed_on: Date.new(2026, 8, 1), due_on: Date.new(2026, 12, 1), money_account: loans)
    recent = create(:loan, person: producer.person, cash_amount: 2_000, monthly_interest_rate: 0, disbursed_on: Date.new(2026, 10, 10), due_on: Date.new(2026, 12, 1), money_account: loans)
    cash = create(:loan_payment, loan: recent, amount: 500, payment_method: "cash", paid_on: Date.new(2026, 10, 20), money_account: loans)
    coffee = create(:loan_payment, loan: old, amount: 300, payment_method: "coffee", purchase: create(:purchase, producer:), paid_on: Date.new(2026, 10, 20))
    coffee.update_columns(money_account_id: loans.id)

    task = described_class.new
    expect(task.sections.first.lines.join).to include("1 préstamos desde la apertura", "1 préstamos de antes", "1 abonos en dinero", "1 abonos con café")
    changes = task.apply!

    expect(recent.reload.money_account).to eq(box)
    expect(old.reload).to have_attributes(money_account: nil, outside_cash: true)
    expect(cash.reload.money_account).to eq(box)
    expect(coffee.reload.money_account).to be_nil
    expect(loans.reload).to have_attributes(active: false, default_for: [])
    expect(AccountBalance.new.for(box)).to eq(10_000 - 2_000 + 500)
    expect(MoneyMovements.new(account: :none).all.select { it.source == "loans" }).to be_empty

    described_class.revert!(changes)
    expect(recent.reload.money_account).to eq(loans)
    expect(old.reload).to have_attributes(money_account: loans, outside_cash: false)
    expect(loans.reload).to have_attributes(active: true, default_for: %w[loans])
  end

  it "takes the old portfolio back into the money once it is given an account" do
    loan = create(:loan, person: producer.person, cash_amount: 1_000, money_account: nil)
    loan.update_columns(outside_cash: true)
    loan.update!(money_account: box)
    expect(loan.reload.outside_cash).to be(false)
  end
end
