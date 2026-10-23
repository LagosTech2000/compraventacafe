require "rails_helper"

# The "Préstamos" tab of a payroll: each member's debt and account, and a
# payment to their loans that comes back to the payroll.
RSpec.describe "Payroll loans tab" do
  let(:admin) { create(:user, :admin) }
  let(:payroll) { create(:payroll, starts_on: Time.zone.today - 10) }
  let!(:owing) { create(:payroll_member, payroll:, person: create(:person, :collaborator, first_names: "Ana", last_names: "Zelaya")) }
  let!(:clear) { create(:payroll_member, payroll:, person: create(:person, :collaborator, first_names: "Beto", last_names: "Paz")) }
  let!(:loan) { create(:loan, person: owing.person, cash_amount: 1_000, monthly_interest_rate: 0) }
  let!(:overdue) do
    create(:loan, person: owing.person, cash_amount: 500, monthly_interest_rate: 0,
                  disbursed_on: Time.zone.today - 60, due_on: Time.zone.today - 1)
  end

  def page = Nokogiri::HTML(response.body)

  def user_with(*grants)
    create(:user).tap do |user|
      grants.each { |module_key, actions| create(:permission, user:, module_key:, **actions.to_h { [ :"can_#{it}", true ] }) }
    end
  end

  it "lists what each member owes today, their account and a payment for each open loan" do
    sign_in admin
    get farms_payroll_path(payroll, tab: "loans")

    expect(response).to have_http_status(:ok)
    row = page.at_css("tr##{ActionView::RecordIdentifier.dom_id(owing, :loans)}")
    expect(row.text).to include("Ana Zelaya", "Préstamo #{loan.id}", "Préstamo #{overdue.id}", "L 1,500.00")
    expect(row.at_css("a[href='#{loans_credit_account_path(owing.person)}']")).to be_present
    expect(row.at_css("a[href='#{new_loans_loan_payment_path(loan, payroll_id: payroll.id)}']")).to be_present
    expect(page.at_css("tr##{ActionView::RecordIdentifier.dom_id(clear, :loans)}").text).to include("Sin préstamos por cobrar")
    expect(page.css(".stat").map(&:text).join).to include("L 1,500.00")
    expect(response.body).to include("Préstamos de los empleados") # its help guide
  end

  it "filters members by standing and name" do
    sign_in admin

    get farms_payroll_path(payroll, tab: "loans", standing: "overdue")
    expect(response.body).to include("Ana Zelaya")
    expect(response.body).not_to include("Beto Paz")

    get farms_payroll_path(payroll, tab: "loans", standing: "clear")
    expect(response.body).to include("Beto Paz")
    expect(response.body).not_to include("Ana Zelaya")

    get farms_payroll_path(payroll, tab: "loans", q: "beto")
    expect(response.body).to include("Beto Paz")
    expect(response.body).not_to include("Ana Zelaya")
  end

  it "registers a payment from the payroll and comes back to it with the receipt" do
    sign_in admin
    get new_loans_loan_payment_path(loan, payroll_id: payroll.id)
    expect(response.body).to include(payroll.name, %(name="payroll_id"))

    post loans_loan_payments_path(loan), params: { payroll_id: payroll.id,
                                                   loan_payment: { paid_on: Time.zone.today, amount: "200", payment_method: "cash" } }
    payment = loan.payments.last
    expect(payment).to have_attributes(amount: 200, payment_method: "cash")
    expect(response).to redirect_to(farms_payroll_path(payroll, tab: "loans", receipt_loan: loan.id, receipt: payment.id))

    follow_redirect!
    expect(page.at_css("turbo-frame#modal")["src"]).to eq(loans_loan_payment_path(loan, payment))
  end

  it "goes back to the loan when the payroll is not one the user sees" do
    user = user_with([ "loans", %w[read create] ])
    sign_in user
    post loans_loan_payments_path(loan), params: { payroll_id: payroll.id,
                                                   loan_payment: { paid_on: Time.zone.today, amount: "50", payment_method: "cash" } }
    expect(response).to redirect_to(loans_loan_path(loan, receipt: loan.payments.last.id))
  end

  it "shows the tab only to who sees the loans module, and the payment only to who creates loans" do
    sign_in user_with([ "farms", %w[read] ])
    get farms_payroll_path(payroll)
    expect(response.body).not_to include(farms_payroll_path(payroll, tab: "loans"))
    get farms_payroll_path(payroll, tab: "loans")
    expect(page.at_css("nav[aria-label='Secciones de la planilla'] [aria-current=page]").text).to eq("Períodos de pago")

    sign_in user_with([ "farms", %w[read] ], [ "loans", %w[read] ])
    get farms_payroll_path(payroll, tab: "loans")
    expect(response.body).to include("Ana Zelaya", loans_credit_account_path(owing.person))
    expect(response.body).not_to include(new_loans_loan_payment_path(loan, payroll_id: payroll.id))
  end

  it "links each employee who owes to their account when paying a period" do
    sign_in admin
    period = payroll.periods.first
    patch farms_payroll_timesheet_path(payroll, period: period.to_param),
          params: { work: { owing.id.to_s => { period.starts_on.iso8601 => "1" } } }
    get new_farms_payroll_payment_path(payroll, period: period.to_param)
    expect(response.body).to include(loans_credit_account_path(owing.person), "Préstamos de los empleados")
  end
end
