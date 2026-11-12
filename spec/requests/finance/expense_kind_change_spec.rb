require "rails_helper"

# Editing, an expense can become an investment and back (Fernando,
# 2026-11-12), with a category of the new kind; it takes creating in the
# other tab, and one assigned to a shipment stays an expense.
RSpec.describe "Changing an expense into an investment" do
  let(:admin) { create(:user, :admin) }
  let(:expense) { create(:expense, description: "Bomba de agua") }
  let(:investment_category) { create(:finance_category, kind: "investment") }

  def page = Nokogiri::HTML(response.body)
  def patch_kind(record, kind, category, path: finance_expense_path(record))
    patch path, params: { expense: { kind:, finance_category_id: category.id, description: record.description, spent_on: record.spent_on,
                                     amount: record.amount, payment_method: record.payment_method, money_account_id: record.money_account_id,
                                     lock_version: record.lock_version } }
  end

  it "offers the kind and a category list per kind, and moves it to investments" do
    sign_in admin
    get edit_finance_expense_path(expense)
    expect(page.css("input[name='expense[kind]']").map { it["value"] }).to eq(%w[expense investment])
    expect(page.css("[data-expense-kind-target='panel']").map { it["data-kind"] }).to eq(%w[expense investment])

    patch_kind(expense, "investment", investment_category)
    expect(expense.reload).to have_attributes(kind: "investment", category: investment_category)

    patch_kind(expense, "expense", investment_category, path: finance_investment_path(expense))
    expect(response).to have_http_status(:unprocessable_content)
    expect(expense.reload).to be_investment
  end

  it "takes creating in the other tab" do
    user = create(:user).tap do
      create(:permission, user: it, module_key: "finance", submodule_key: "expenses", can_read: true, can_update: true, can_create: true)
      create(:permission, user: it, module_key: "finance", submodule_key: "investments", can_read: true)
    end
    sign_in user
    get edit_finance_expense_path(expense)
    expect(page.css("input[name='expense[kind]']")).to be_empty
    patch_kind(expense, "investment", investment_category)
    expect(expense.reload).not_to be_investment
  end

  it "keeps one assigned to a shipment as an expense" do
    shipment = create(:shipment)
    expense.update!(shipment:)
    sign_in admin
    patch_kind(expense, "investment", investment_category)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("está asignado a la salida")
  end
end
