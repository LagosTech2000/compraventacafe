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

  it "marks movements without an account and gives them one" do
    loans = create_list(:loan, 2, cash_amount: 500)
    visit finance_consolidation_path
    expect(page).to have_button("Asignar a los marcados", disabled: true)
    check "Marcar todos"
    expect(page).to have_text("2 marcados")
    select "Banco Atlántida", from: "account_id"
    accept_confirm { click_button "Asignar a los marcados" }
    expect(page).to have_text("Se asignó la cuenta a 2 movimientos.")
    expect(loans.map { it.reload.money_account }).to all(eq(bank))
  end

  it "shows the accounts as cards in their bank's colors that open their detail, and picks the bank or types another" do
    create(:money_account, name: "Cheques", kind: "bank", bank_key: "ficohsa", account_number: "2100 4455 1234")
    visit finance_money_accounts_path
    expect(page).to have_css(".bank-card-ficohsa", text: "•••• 1234")
    expect(page).to have_css(".bank-card-cash", text: "Caja de la bodega")
    find(".bank-card-ficohsa").click
    expect(page).to have_css("h1", text: "Cheques")
    expect(page).to have_text("Datos de la cuenta")

    visit new_finance_money_account_path
    expect(page).to have_no_field("money_account_bank_key")
    fill_in "money_account_name", with: "Ahorros"
    select "Banco", from: "money_account_kind"
    select "BAC Honduras", from: "money_account_bank_key"
    expect(page).to have_no_field("money_account_bank_name")
    select "Otro banco (escribirlo)", from: "money_account_bank_key"
    fill_in "money_account_bank_name", with: "Banpaís"
    click_button "Crear Cuenta"
    expect(page).to have_text("Cuenta registrada")
    expect(MoneyAccount.find_by(name: "Ahorros")).to have_attributes(bank_key: "other", bank_name: "Banpaís")
  end

  it "suggests the account when paying an invoice" do
    invoice = create(:invoice)
    visit trading_invoice_path(invoice)
    click_link "Registrar abono"
    select "Transferencia", from: "invoice_payment_payment_method"
    expect(page).to have_select("invoice_payment_money_account_id", selected: "Banco Atlántida")
  end
end
