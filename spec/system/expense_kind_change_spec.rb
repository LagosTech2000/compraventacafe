require "rails_helper"

# Editing an expense, its kind changes and the categories follow (Fernando, 2026-11-12).
RSpec.describe "Expense kind change", type: :system do
  it "shows the categories of the kind chosen and saves it as an investment" do
    expense = create(:expense, description: "Bomba de agua")
    create(:finance_category, kind: "investment", name: "Maquinaria")
    sign_in_as(create(:user, :admin))
    visit edit_finance_expense_path(expense)

    expect(page).to have_select("expense_finance_category_id_expense")
    expect(page).to have_no_select("expense_finance_category_id_investment")
    choose "Inversión"
    expect(page).to have_no_select("expense_finance_category_id_expense")
    select "Maquinaria", from: "expense_finance_category_id_investment"
    click_button "Guardar cambios"

    expect(page).to have_css(".toast")
    expect(expense.reload).to be_investment
    expect(expense.category.name).to eq("Maquinaria")
  end
end
