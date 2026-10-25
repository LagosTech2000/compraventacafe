require "rails_helper"

# Control financiero (Fernando, 2026-10-23): accounts with their balance,
# expenses and investments with their receipt, other income, transfers,
# the budget, and every module's payments in one ledger.
RSpec.describe "Finance flow" do
  let(:user) do
    create(:user).tap do |u|
      create(:permission, user: u, module_key: "finance", can_read: true, can_create: true, can_update: true, can_destroy: true)
    end
  end

  before { sign_in user }

  it "registers accounts, an expense with its receipt, other income and a transfer, and keeps each balance" do
    post finance_money_accounts_path, params: { money_account: { name: "Caja de la bodega", kind: "cash", bank_key: "bac", bank_name: "X", opening_balance: "5000",
                                                                 opening_on: Time.zone.today - 10, default_for: [ "", "cash" ] } }
    box = MoneyAccount.find_by!(name: "Caja de la bodega")
    expect(box).to have_attributes(default_for: [ "cash" ], bank_key: nil, bank_name: nil, card_style: "cash")
    bank = create(:money_account, name: "Banco Atlántida", kind: "bank", opening_balance: 20_000, default_for: %w[transfer check])
    fuel = create(:finance_category, name: "Combustible", parent: create(:finance_category, name: "Transporte"))

    get new_finance_expense_path
    expect(response.body).to include("Transporte › Combustible")
    post finance_expenses_path, params: { expense: {
      description: "Diésel del camión", finance_category_id: fuel.id, payee: "Gasolinera Demo", spent_on: Time.zone.today,
      amount: "1200", payment_method: "cash", money_account_id: box.id, receipt_number: "F-001", receipt_upload: uploaded_picture
    } }
    expense = Expense.last
    expect(response).to redirect_to(finance_expense_path(expense))
    expect(expense.receipt).to have_attributes(content_type: "image/png")
    get finance_expense_path(expense)
    expect(response.body).to include("Gasolinera Demo", "Transporte › Combustible", finance_expense_receipt_path(expense.receipt, v: expense.receipt.version))
    get finance_expense_receipt_path(expense.receipt)
    expect(response.media_type).to eq("image/png")

    post finance_other_incomes_path, params: { other_income: { concept: "Aporte del dueño", amount: "3000", received_on: Time.zone.today,
                                                               payment_method: "transfer", money_account_id: bank.id } }
    post finance_account_transfers_path, params: { account_transfer: { from_account_id: bank.id, to_account_id: box.id, amount: "1000",
                                                                       transferred_on: Time.zone.today } }

    balance = AccountBalance.new
    expect(balance.for(box)).to eq(5_000 - 1_200 + 1_000)
    expect(balance.for(bank)).to eq(20_000 + 3_000 - 1_000)

    get finance_money_account_path(box, from: "", to: "")
    expect(response.body).to include("Diésel del camión", "De Banco Atlántida a Caja de la bodega", "L 4,800.00")

    get finance_movements_path
    expect(response.body).to include("Diésel del camión", "Aporte del dueño")
    expect(response.body).not_to include("De Banco Atlántida a Caja de la bodega") # transfers: only with an account

    [ finance_root_path, finance_investments_path, finance_money_accounts_path, finance_categories_path, finance_budget_path,
      new_finance_money_account_path, new_finance_account_transfer_path, new_finance_other_income_path, new_finance_category_path,
      edit_finance_expense_path(expense), edit_finance_money_account_path(box) ].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
  end

  it "refuses a receipt that is not a photo or a PDF" do
    category = create(:finance_category)
    file = Rack::Test::UploadedFile.new(StringIO.new("<svg></svg>"), "image/svg+xml", original_filename: "x.svg")
    post finance_expenses_path, params: { expense: { description: "Algo", finance_category_id: category.id, spent_on: Time.zone.today,
                                                     amount: "10", payment_method: "cash", money_account_id: create(:money_account).id, receipt_upload: file } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("debe ser una foto (JPG, PNG o WebP) o un PDF")
  end

  it "saves the season's budget and compares it with the spending" do
    transport = create(:finance_category, name: "Transporte")
    month = Time.zone.today.beginning_of_month
    patch finance_budget_path, params: { budgets: { transport.id => { month.iso8601 => "1000" } } }
    expect(Budget.sole).to have_attributes(amount: 1_000, month:)
    create(:expense, category: create(:finance_category, name: "Diésel", parent: transport), amount: 1_500)

    get finance_budget_path
    expect(response.body).to include("Gastado L 1,500.00 · 150.0 %")
    get finance_root_path
    expect(response.body).to include("Transporte pasó su presupuesto del mes")

    patch finance_budget_path, params: { budgets: { transport.id => { month.iso8601 => "" } } }
    expect(Budget.count).to eq(0)
  end

  it "gives an account to what was registered without one, chosen or by its payment method" do
    create(:permission, user:, module_key: "trading", can_read: true)
    create(:permission, user:, module_key: "loans", can_read: true)
    box = create(:money_account, name: "Caja", default_for: %w[cash])
    bank = create(:money_account, name: "Banco", kind: "bank")
    invoice = create(:invoice)
    cash = invoice.payments.create!(amount: 10, paid_on: Time.zone.today, payment_method: "cash", created_by: user)
    check = invoice.payments.create!(amount: 10, paid_on: Time.zone.today, payment_method: "check", created_by: user)
    loan = create(:loan, cash_amount: 500)

    get finance_consolidation_path
    expect(response.body).to include("3 movimientos sin cuenta", "Factura #{invoice.display_number}", "Préstamo #{loan.id}")

    patch finance_consolidation_path, params: { by_method: "1", items: [ "invoices:#{cash.id}", "invoices:#{check.id}", "loans:#{loan.id}" ] }
    expect(flash[:notice]).to include("Se asignó la cuenta a 2 movimientos.", "1 movimiento sin cuenta sugerida quedó pendiente.")
    expect([ cash.reload.money_account, check.reload.money_account, loan.reload.money_account ]).to eq([ box, nil, box ])

    patch finance_consolidation_path, params: { account_id: bank.id, items: [ "invoices:#{check.id}", "invoices:#{cash.id}" ] }
    expect(check.reload.money_account).to eq(bank)
    expect(cash.reload.money_account).to eq(box) # it already had one
    expect(AuditEvent.where(auditable: check, action: "update").last.changeset).to include("money_account_id")

    patch finance_consolidation_path, params: { items: [ "invoices:#{check.id}" ] }
    expect(flash[:alert]).to eq("Elige la cuenta que les vas a asignar.")
  end

  it "takes the account in every module's payments, suggested by the payment method" do
    create(:permission, user:, module_key: "trading", can_read: true, can_update: true)
    bank = create(:money_account, name: "Banco", kind: "bank", default_for: %w[transfer])
    invoice = create(:invoice)
    get new_trading_invoice_payment_path(invoice)
    expect(response.body).to include("data-money-account-defaults-value", "Banco")
    post trading_invoice_payments_path(invoice), params: { invoice_payment: { amount: "100", paid_on: Time.zone.today, payment_method: "transfer",
                                                                              money_account_id: bank.id } }
    expect(InvoicePayment.last.money_account).to eq(bank)
    expect(AccountBalance.new.for(bank)).to eq(-100)

    get finance_movements_path(account: bank.id)
    expect(response.body).to include("Factura #{invoice.display_number}")
  end
end
