require "rails_helper"

RSpec.describe "Finance policies" do
  def member(**flags)
    create(:user).tap { |u| create(:permission, user: u, module_key: "finance", **flags) }.reload
  end

  [ MoneyAccountPolicy, FinanceCategoryPolicy, ExpensePolicy, ExpenseReceiptPolicy, OtherIncomePolicy, AccountTransferPolicy,
    Finance::HomePolicy, Finance::MovementPolicy, Finance::BudgetPolicy, Finance::ConsolidationPolicy ].each do |policy|
    it "#{policy} belongs to the finance module" do
      expect(policy.module_key).to eq("finance")
      expect(policy.new(create(:user), nil)).to forbid_action(:index)
    end
  end

  it "never deletes accounts nor categories, and never edits income or transfers" do
    full = member(can_read: true, can_create: true, can_update: true, can_destroy: true)
    expect(MoneyAccountPolicy.new(full, build(:money_account))).to forbid_action(:destroy)
    expect(FinanceCategoryPolicy.new(full, build(:finance_category))).to forbid_action(:destroy)
    expect(OtherIncomePolicy.new(full, build(:other_income))).to forbid_action(:update)
    expect(AccountTransferPolicy.new(full, build(:account_transfer))).to forbid_action(:update)
    expect(ExpensePolicy.new(full, build(:expense))).to permit_actions(%i[edit update destroy])
  end
end
