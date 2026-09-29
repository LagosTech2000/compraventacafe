require "rails_helper"

RSpec.describe "Loans policies" do
  def lender(**flags)
    create(:user).tap { |u| create(:permission, user: u, module_key: "loans", **flags) }.reload
  end

  let(:full) { lender(can_read: true, can_create: true, can_update: true, can_destroy: true) }

  [ LoanPolicy, LoanPaymentPolicy, Loans::CreditAccountPolicy, Loans::HomePolicy ].each do |policy|
    it "#{policy} belongs to the loans module" do
      expect(policy.module_key).to eq("loans")
      expect(policy.new(create(:user), nil)).to forbid_action(:index)
    end
  end

  describe LoanPolicy do
    it "lets a user change a loan without payments" do
      expect(described_class.new(full, create(:loan))).to permit_actions(%i[edit update destroy])
    end

    it "freezes a loan with payments, even for an admin" do
      loan = create(:loan_payment).loan
      expect(described_class.new(full, loan)).to forbid_actions(%i[edit update destroy])
      expect(described_class.new(create(:user, :admin), loan)).to forbid_actions(%i[edit update destroy])
    end
  end

  describe LoanPaymentPolicy do
    it "only removes the latest payment and never edits one" do
      loan = create(:loan)
      first = create(:loan_payment, loan:, paid_on: Time.zone.today - 2, amount: 100)
      last = create(:loan_payment, loan:, paid_on: Time.zone.today - 1, amount: 100)

      expect(described_class.new(full, first)).to forbid_actions(%i[destroy update])
      expect(described_class.new(full, last)).to permit_action(:destroy)
    end

    it "takes no payments on a paid-off loan" do
      loan = create(:loan, paid_off_on: Time.zone.today)
      expect(described_class.new(full, LoanPayment.new(loan:))).to forbid_action(:create)
      expect(described_class.new(full, LoanPayment.new(loan: create(:loan)))).to permit_action(:create)
    end
  end
end
