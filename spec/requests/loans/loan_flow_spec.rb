require "rails_helper"

RSpec.describe "Loans flow" do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, :collaborator) }

  before { sign_in admin }

  it "lends to any person, takes payments and pays the loan off" do
    post loans_loans_path, params: { loan: { person_id: person.id, principal: "1000", monthly_interest_rate: "3",
                                             disbursed_on: Time.zone.today - 30, due_on: Time.zone.today + 30 } }
    loan = Loan.last
    expect(response).to redirect_to(loans_loan_path(loan))
    expect([ loan.person, loan.created_by ]).to eq([ person, admin ])

    get loans_loan_path(loan)
    expect(response.body).to include("L 1,030.00")

    post loans_loan_payments_path(loan), params: { loan_payment: { paid_on: Time.zone.today, amount: "1030", payment_method: "cash" } }
    expect(loan.reload).to be_paid_off
    expect(loan.payments.last.interest_amount).to eq(30)
  end

  it "shows the error in Spanish when a payment is too large" do
    loan = create(:loan, principal: 100, monthly_interest_rate: 0)
    post loans_loan_payments_path(loan), params: { loan_payment: { paid_on: Time.zone.today, amount: "200", payment_method: "cash" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("es mayor que lo que se debe a esa fecha")
  end

  it "removes only the latest payment" do
    loan = create(:loan)
    first = create(:loan_payment, loan:, paid_on: Time.zone.today - 1, amount: 50)
    create(:loan_payment, loan:, amount: 50)

    delete loans_loan_payment_path(loan, first)
    expect(LoanPayment.exists?(first.id)).to be(true)
  end

  it "shows a person's account with the score and the full history" do
    loan = create(:loan, person:, principal: 500, monthly_interest_rate: 0, disbursed_on: Time.zone.today - 40, due_on: Time.zone.today - 10)
    create(:loan_payment, loan:, paid_on: Time.zone.today - 20, amount: 500)
    create(:loan, person:, disbursed_on: Time.zone.today - 5, due_on: Time.zone.today + 30)

    get loans_credit_account_path(person)
    page = Nokogiri::HTML(response.body)
    expect(page.text).to include("100 · Excelente", "1 de 1 préstamo pagado a tiempo")
    expect(page.at_css("main").text).to include("Préstamo #{loan.id} otorgado", "Abono al préstamo #{loan.id}")

    get loans_credit_accounts_path
    expect(response.body).to include(person.full_name)
  end

  it "lists overdue loans on the module home" do
    create(:loan, person:, disbursed_on: Time.zone.today - 60, due_on: Time.zone.today - 1)
    get loans_root_path

    expect(Nokogiri::HTML(response.body).at_css("main").text).to include(person.full_name)
  end

  it "renders every screen of the module, as a page and in the modal" do
    loan = create(:loan, person:)
    create(:loan_payment, loan:)
    paths = [ loans_root_path, loans_loans_path, new_loans_loan_path, new_loans_loan_path(person_id: person.id),
              edit_loans_loan_path(create(:loan)), loans_loan_path(loan), new_loans_loan_payment_path(loan),
              loans_credit_accounts_path, loans_credit_account_path(person) ]

    paths.each do |path|
      [ {}, { "Turbo-Frame" => "modal" } ].each do |headers|
        get(path, headers:)
        expect(response).to have_http_status(:ok), "#{path} #{headers}"
      end
    end
  end

  it "keeps a read-only user from lending" do
    reader = create(:user).tap { |u| create(:permission, user: u, module_key: "loans", can_read: true) }
    sign_in reader
    get loans_root_path
    expect(response.body).not_to include(new_loans_loan_path)
    expect { post loans_loans_path, params: { loan: { person_id: person.id, principal: 1 } } }.not_to change(Loan, :count)
  end
end
