require "rails_helper"

RSpec.describe "Loans flow" do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, :collaborator) }

  before { sign_in admin }

  it "lends to any person, takes payments and pays the loan off" do
    post loans_loans_path, params: { loan: { person_id: person.id, cash_amount: "1000", monthly_interest_rate: "3",
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

  it "opens a printable receipt for each payment, with the balance right after it" do
    loan = create(:loan, person:, cash_amount: 1_000, monthly_interest_rate: 0, disbursed_on: Time.zone.today - 10)
    post loans_loan_payments_path(loan), params: { loan_payment: { paid_on: Time.zone.today - 5, amount: "300", payment_method: "cash" } },
                                         headers: { "Turbo-Frame" => "modal" }
    first = loan.payments.last
    expect(response.body).to include(%(data-modal-result-visit-value="#{loans_loan_path(loan, receipt: first.id)}"))

    get loans_loan_path(loan, receipt: first.id)
    expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal")["src"]).to eq(loans_loan_payment_path(loan, first))
    create(:loan_payment, loan:, amount: 200)

    get loans_loan_payment_path(loan, first)
    page = Nokogiri::HTML(response.body)
    expect(page.css("article").size).to eq(2) # original and copy
    expect(page.text).to include("ORIGINAL", "COPIA", "Recibo de abono #{first.display_number}", person.full_name,
                                 "L 300.00", "L 700.00") # what was owed right after it, not today

    get loans_loan_payment_path(loan, first), headers: { "Turbo-Frame" => "modal" }
    expect(Nokogiri::HTML(response.body).css("article").size).to eq(1)

    loan.payments.last.update_columns(amount: 1_000, principal_amount: 700)
    get loans_loan_payment_path(loan, loan.payments.last)
    expect(response.body).to include("Préstamo saldado")
  end

  it "shows the error in Spanish when a payment is too large" do
    loan = create(:loan, cash_amount: 100, monthly_interest_rate: 0)
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
    loan = create(:loan, person:, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: Time.zone.today - 40, due_on: Time.zone.today - 10)
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
              loans_credit_accounts_path, loans_credit_account_path(person),
              loans_supplies_path, new_loans_supply_path, edit_loans_supply_path(create(:supply)),
              edit_loans_loan_path(create(:loan, supply_items_attributes: [ { supply_id: create(:supply).id, quantity: 1, unit_price: 5 } ])) ]

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

  describe "supplies" do
    it "registers a supply and hands it to the loan form from the modal" do
      post loans_supplies_path, headers: { "Turbo-Frame" => "modal_2" },
                                params: { picker: "1", supply: { name: " Abono  18-46-0 ", unit: "Saco", default_price: "1250" } }
      supply = Supply.last
      expect(supply).to have_attributes(name: "Abono 18-46-0", unit: "saco", default_price: 1_250, active: true)
      result = Nokogiri::HTML(response.body).at_css("turbo-frame#modal_2 [data-controller='modal-result']")
      expect(result["data-modal-result-event-value"]).to eq("supply:created")
      expect(JSON.parse(result["data-modal-result-detail-value"])).to eq("id" => supply.id, "name" => "Abono 18-46-0", "unit" => "saco", "price" => "1250.00")
    end

    it "lists active supplies by default and deactivates them instead of deleting" do
      supply = create(:supply, name: "Urea")
      patch loans_supply_path(supply), params: { supply: { active: "0" } }
      expect(supply.reload.active).to be(false)
      get loans_supplies_path
      expect(response.body).not_to include("Urea")
      get loans_supplies_path(status: "inactive")
      expect(response.body).to include("Urea")
    end
  end

  describe "mixed loans" do
    it "lends cash plus supplies at a price changed on the form" do
      supply = create(:supply, name: "Abono 18-46-0", default_price: 1_250)
      post loans_loans_path, params: { loan: {
        person_id: person.id, cash_amount: "2000", monthly_interest_rate: "2",
        disbursed_on: Time.zone.today, due_on: Time.zone.today + 90,
        supply_items_attributes: { "1700000000000" => { supply_id: supply.id, quantity: "3", unit_price: "1200", _destroy: "0" } }
      } }
      loan = Loan.last
      expect(loan).to have_attributes(cash_amount: 2_000, principal: 5_600, kind: "mixed")
      expect(loan.supply_items.first).to have_attributes(quantity: 3, unit_price: 1_200, total: 3_600)

      get loans_loan_path(loan)
      expect(response.body).to include("Mixto", "Insumos prestados", "Abono 18-46-0", "3 saco", "L 3,600.00", "L 5,600.00")
    end

    it "offers active supplies with their default price to the form, and filters loans by kind" do
      create(:supply, name: "Urea", default_price: 1_100)
      create(:supply, name: "Viejo", active: false)
      get new_loans_loan_path
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("template select").css("option").map(&:text)).to eq([ "Selecciona un insumo", "Urea" ])
      supplies = JSON.parse(page.at_css("[data-loan-composition-supplies-value]")["data-loan-composition-supplies-value"])
      expect(supplies.values.map { |s| s["price"] }).to include("1100.00")

      cash = create(:loan, person:, cash_amount: 10)
      supplies_only = create(:loan, person:, cash_amount: 0, supply_items_attributes: [ { supply_id: Supply.first.id, quantity: 1, unit_price: 5 } ])
      get loans_loans_path(kind: "supplies")
      body = response.body
      expect(body).to include("loan_#{supplies_only.id}")
      expect(body).not_to include("loan_#{cash.id}\"")
    end
  end
end
