require "rails_helper"

# Control financiero → Préstamos de los dueños (Fernando, 2026-11-15): what
# the owners owe a bank or another person, with optional interest; a
# payment pays the interest first; with an account, the money moves.
RSpec.describe "Owners' loans" do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }
  let(:bank) { create(:money_account, name: "Banco", kind: "bank", opening_balance: 0) }

  def page = Nokogiri::HTML(response.body)

  before do
    PaidFeature.ensure_all!.find { it.key == "owner_loans" }.update!(enabled: true)
    sign_in admin
  end

  it "registers a loan with interest, splits a payment interest first, and moves the account" do
    travel_to Date.new(2026, 11, 1) do
      post finance_owner_loans_path, params: { owner_loan: { owner_name: "Don Rey", lender_name: "Banco Atlántida", disbursed_on: "2026-10-02",
                                                             principal: "10000", monthly_interest_rate: "3", money_account_id: bank.id } }
    end
    loan = OwnerLoan.sole
    expect(AccountBalance.new.for(bank)).to eq(10_000)

    travel_to Date.new(2026, 11, 1) do
      get finance_owner_loan_path(loan)
      expect(page.text).to include("L 300.00") # 30 days at 3 %

      post finance_owner_loan_payments_path(loan), params: { owner_loan_payment: { paid_on: "2026-11-01", amount: "1300", payment_method: "transfer", money_account_id: bank.id } }
      expect(loan.payments.sole).to have_attributes(interest_amount: 300, principal_amount: 1_000)
      expect(loan.reload.balance.principal_owed).to eq(9_000)
      expect(AccountBalance.new.for(bank)).to eq(8_700)
      expect(MoneyMovements.new(account: bank.id).all.map(&:source)).to eq(%w[owner_loans owner_loan_payments])

      post finance_owner_loan_payments_path(loan), params: { owner_loan_payment: { paid_on: "2026-11-01", amount: "99999", payment_method: "cash" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("es mayor que lo que se debe a esa fecha")

      patch finance_owner_loan_path(loan), params: { owner_loan: { principal: "20000" } }
      expect(loan.reload.principal).to eq(10_000)

      delete finance_owner_loan_payment_path(loan, loan.payments.sole)
      expect(loan.payments.reload).to be_empty
    end
  end

  it "lists them with filters and the totals of what is filtered" do
    OwnerLoan.create!(owner_name: "Don Rey", lender_name: "Banco Atlántida", disbursed_on: Date.current, principal: 5_000, created_by: admin)
    OwnerLoan.create!(owner_name: "Doña Ana", lender_name: "Cooperativa", disbursed_on: Date.current, principal: 2_000, created_by: admin)
    get finance_owner_loans_path(q: "coop")
    expect(page.css("tbody tr").size).to eq(1)
    expect(page.at_css("[data-total=principal] dd").text).to eq("L 2,000.00")
    get finance_root_path
    expect(page.css(".subnav a").map(&:text)).to include("Préstamos de los dueños")
  end
end
