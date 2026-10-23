require "rails_helper"

# A loan's steps (Fernando, 2026-10-18): lent → with payments → paid off.
RSpec.describe LoanLifecycle do
  it "follows the loan's payments" do
    loan = create(:loan, cash_amount: 1_000, monthly_interest_rate: 0, disbursed_on: Time.zone.today - 10)
    expect(described_class.for(loan).stage).to eq("lent")

    create(:loan_payment, loan:, amount: 400)
    expect(described_class.for(loan.reload).stage).to eq("repaying")

    create(:loan_payment, loan:, amount: 600)
    lifecycle = described_class.for(loan.reload)
    expect(lifecycle.stage).to eq("paid")
    expect(lifecycle).to be_complete
  end
end

RSpec.describe "Loan lifecycle on its page", type: :request do
  it "shows the steps, the next one and that it is overdue" do
    sign_in create(:user, :admin)
    loan = create(:loan, disbursed_on: Time.zone.today - 90, due_on: Time.zone.today - 1)

    get loans_loan_path(loan)

    section = Nokogiri::HTML(response.body).at_css("section[aria-label='Etapas del préstamo']")
    expect(section.at_css("[aria-current=step]").text).to include("Con abonos")
    expect(section.text).to include("Siguiente paso: registrar los abonos", "Vencido: la fecha límite era", "Registrar abono")
  end
end
