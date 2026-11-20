require "rails_helper"

RSpec.describe MoneyAccount do
  # The loans' account (Fernando, 2026-11-01).
  describe "the loans' account" do
    it "goes alone, in one account only, and is the one the loans start with" do
      box = create(:money_account, name: "Caja", default_for: %w[cash])
      loans = create(:money_account, name: "Préstamos", default_for: %w[cash transfer loans])
      expect(loans.default_for).to eq(%w[loans])
      expect(described_class.for_loans).to eq(loans)
      expect(described_class.default_for("cash")).to eq(box)
      expect(described_class.defaults_by_method).not_to have_value(loans.id)

      other = build(:money_account, default_for: %w[loans])
      expect(other).not_to be_valid
      expect(other.errors[:base]).to eq([ "Solo una cuenta puede ser la de préstamos, y ya lo es Préstamos: quítaselo ahí primero." ])
      expect { other.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)

      # Not deactivated while it is the loans' one (Fernando, 2026-11-20).
      expect(loans.update(active: false)).to be(false)
      expect(loans.errors[:base]).to eq([ "La cuenta de préstamos no se desactiva: a ella entran los abonos con café." ])
      loans.update!(active: false, default_for: %w[cash])
      expect(described_class.for_loans).to be_nil
      expect(described_class.human_suggestion("loans")).to eq("Préstamos")
    end
  end

  # The loan payments with coffee enter the loans' account (Fernando,
  # 2026-11-20); the ones from a payroll, none.
  it "takes the payments with coffee in the loans' account, not the payroll ones" do
    loans = create(:money_account, name: "Préstamos", default_for: %w[loans], opening_balance: 0)
    producer = create(:producer)
    loan = create(:loan, person: producer.person, money_account: nil)
    payment = create(:loan_payment, loan:, amount: 500, payment_method: "coffee", purchase: create(:purchase, producer:))
    expect(payment.money_account).to eq(loans)
    expect(AccountBalance.new.for(loans)).to eq(500)

    movement = MoneyMovements.new(account: loans.id).all.sole
    expect(movement).to have_attributes(source: "loan_payments", amount_in: 500)
  end
end
