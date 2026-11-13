require "rails_helper"

# Administrators see everything; whoever is not one sees, and works on,
# only what they registered (Fernando, 2026-11-13): lists, details,
# summaries, the Inicio, daily closes, reports and the money movements.
# Catalogs are shared; the coffee stock and the accounts' balances are of
# the whole business.
RSpec.describe "Own records" do
  let(:admin) { create(:user, :admin) }
  let(:ana) { user_with("trading", "loans", "sales", "finance", "reports") }
  let(:bruno) { user_with("trading", "loans", "sales", "finance", "reports") }
  let(:producer) { create(:producer, person: create(:person, first_names: "Rosa", last_names: "Mejía")) }

  def page = Nokogiri::HTML(response.body)

  def user_with(*modules)
    create(:user).tap do |user|
      modules.each { create(:permission, user:, module_key: it, can_read: true, can_create: true, can_update: true, can_destroy: true) }
    end.reload
  end

  it "lists and opens only what each one registered; an administrator sees all" do
    mine = create(:purchase, producer:, created_by: ana)
    theirs = create(:purchase, producer:, created_by: bruno)

    sign_in ana
    get trading_purchases_path
    expect(response.body).to include("id=\"purchase_#{mine.id}\"")
    expect(response.body).not_to include("id=\"purchase_#{theirs.id}\"")
    get trading_purchase_path(theirs)
    expect(response).to redirect_to(root_path)
    get trading_purchase_path(mine)
    expect(response).to have_http_status(:ok)

    sign_in admin
    get trading_purchases_path
    expect(response.body).to include("id=\"purchase_#{mine.id}\"", "id=\"purchase_#{theirs.id}\"")
  end

  it "counts only theirs in the Inicio, the daily close and the reports, and invoices only theirs" do
    mine = create(:purchase, producer:, created_by: ana, gross_weight: 100)
    create(:purchase, producer:, created_by: bruno, gross_weight: 300)

    sign_in ana
    get root_path
    figures = page.css(".stat").to_h { [ it.at_css("dt")&.text&.strip, it.at_css("dd")&.text&.strip ] }
    expect(figures["Compras de hoy"]).to eq("1")
    get trading_daily_close_path
    expect(response.body).to include("id=\"purchase_#{mine.id}\"")

    expect(PurchasesReport.new({ "period" => "today" }, user: ana).total_count).to eq(1)
    expect(PurchasesReport.new({ "period" => "today" }, user: admin).total_count).to eq(2)

    get new_trading_invoice_path(producer_id: producer.id)
    expect(page.css("input[name='invoice[purchase_ids][]']").map { it["value"] }).to eq([ mine.id.to_s ])
  end

  it "works only on theirs: no payment on someone else's loan" do
    loan = create(:loan, person: producer.person, created_by: bruno)
    sign_in ana
    get new_loans_loan_payment_path(loan)
    expect(response).to redirect_to(root_path)
    expect(LoanPaymentPolicy.new(ana, LoanPayment.new(loan:))).to forbid_action(:create)
    expect(LoanPaymentPolicy.new(bruno, LoanPayment.new(loan:))).to permit_action(:create)
  end

  it "sees inside a record of theirs what others added to it" do
    loan = create(:loan, person: producer.person, created_by: ana, cash_amount: 1_000, monthly_interest_rate: 0)
    payment = create(:loan_payment, loan:, amount: 100, created_by: admin)
    sign_in ana
    get loans_loan_payment_path(loan, payment)
    expect(response).to have_http_status(:ok)
  end

  it "shows only their money movements, and the accounts' balances of the whole business" do
    account = create(:money_account, opening_balance: 1_000)
    create(:expense, money_account: account, amount: 100, description: "Gasto de Ana", created_by: ana)
    create(:expense, money_account: account, amount: 300, description: "Gasto de Bruno", created_by: bruno)

    sign_in ana
    get finance_movements_path
    expect(response.body).to include("Gasto de Ana")
    expect(response.body).not_to include("Gasto de Bruno")
    expect(AccountBalance.new.for(account)).to eq(600)
  end
end
