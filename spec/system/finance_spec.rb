require "rails_helper"

# Control financiero on screen: the account suggested by the payment method
# (money_account_controller.js), in its own forms and in other modules'.
RSpec.describe "Finance screens", type: :system do
  let(:user) { create(:user, :admin) }
  let!(:box) { create(:money_account, name: "Caja de la bodega", default_for: %w[cash]) }
  let!(:bank) { create(:money_account, name: "Banco Atlántida", kind: "bank", default_for: %w[transfer check]) }

  before { sign_in_as(user) }

  it "suggests the account of the payment method until one is picked by hand" do
    create(:finance_category, name: "Transporte")
    visit new_finance_expense_path
    expect(page).to have_select("expense_money_account_id", selected: "Caja de la bodega")
    select "Transferencia", from: "expense_payment_method"
    expect(page).to have_select("expense_money_account_id", selected: "Banco Atlántida")

    select "Caja de la bodega", from: "expense_money_account_id"
    select "Cheque", from: "expense_payment_method"
    expect(page).to have_select("expense_money_account_id", selected: "Caja de la bodega")

    fill_in "expense_description", with: "Diésel del camión"
    select "Transporte", from: "expense_finance_category_id"
    fill_in "expense_amount", with: "1200"
    click_button "Registrar gasto"
    expect(page).to have_text("Gasto registrado")
    expect(Expense.last).to have_attributes(money_account: box, payment_method: "check")
  end

  it "suggests the account when paying an invoice" do
    invoice = create(:invoice)
    visit trading_invoice_path(invoice)
    click_link "Registrar abono"
    select "Transferencia", from: "invoice_payment_payment_method"
    expect(page).to have_select("invoice_payment_money_account_id", selected: "Banco Atlántida")
  end
end
