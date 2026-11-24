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
      expect(loans.errors[:base]).to eq([ "La cuenta sugerida para préstamos no se desactiva: primero quítale «Préstamos» en «Se sugiere para»." ])
      loans.update!(active: false, default_for: %w[cash])
      expect(described_class.for_loans).to be_nil
      expect(described_class.human_suggestion("loans")).to eq("Préstamos")
    end
  end

  # The loan payments with coffee or from a payroll move no money: no
  # account (Fernando, 2026-11-23; with coffee they went to the loans' one).
  it "leaves the payments with coffee out of every account" do
    loans = create(:money_account, name: "Préstamos", default_for: %w[loans], opening_balance: 0)
    producer = create(:producer)
    loan = create(:loan, person: producer.person, money_account: nil)
    payment = create(:loan_payment, loan:, amount: 500, payment_method: "coffee", purchase: create(:purchase, producer:), money_account: loans)
    expect(payment.money_account).to be_nil
    expect(AccountBalance.new.for(loans)).to eq(0)
    expect(MoneyMovements.new.all.map(&:source)).not_to include("loan_payments")
  end
end
