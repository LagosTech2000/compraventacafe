require "rails_helper"

# The card beside the loan form (loans/borrowers#show): who the person is,
# how they pay and, for a producer seen by the user, the coffee they sell.
RSpec.describe "Borrower card" do
  let(:admin) { create(:user, :admin) }

  def card = Nokogiri::HTML(response.body).at_css("turbo-frame#borrower-card")

  it "shows the person's contact, what they owe today and their open loans" do
    person = create(:person, :client, first_names: "Rosa", last_names: "Díaz", dni: "0801199912345", phone: "99990000")
    loan = create(:loan, person:, cash_amount: 1_000, monthly_interest_rate: 0, disbursed_on: Time.zone.today - 90, due_on: Time.zone.today - 1)
    sign_in admin

    get loans_borrower_path(person), headers: { "Turbo-Frame" => "borrower-card" }

    expect(response).to have_http_status(:ok)
    expect(card.text).to include("Rosa Díaz", "0801199912345", "9999-0000", "Cliente", "L 1,000.00", "Préstamo #{loan.id}", "Vencido")
    expect(card.at_css("[data-borrower-owed]")["class"]).to include("text-danger")
    expect(card.at_css("a[href='#{loans_credit_account_path(person)}']")).to be_present
  end

  it "says when it would be the person's first loan" do
    person = create(:person, :collaborator)
    sign_in admin

    get loans_borrower_path(person), headers: { "Turbo-Frame" => "borrower-card" }

    expect(card.text).to include("Sería su primer préstamo", "Sin historial", "Sin DNI, teléfono, correo ni dirección")
    expect(card.at_css("a[href='#{loans_credit_account_path(person)}']")).to be_nil
  end

  it "adds a producer's coffee of the season only for who sees trading" do
    producer = create(:producer, ihcafe_code: "AB-12-34567")
    create(:purchase, producer:)
    sign_in admin

    get loans_borrower_path(producer.person), headers: { "Turbo-Frame" => "borrower-card" }
    expect(card.text).to include("Temporada #{Season.current.label}", "AB-12-34567", "1 compra", "Sin facturar")
    expect(card.at_css("a[href='#{trading_producer_path(producer)}']")).to be_present

    lender = create(:user).tap { create(:permission, user: it, module_key: "loans", can_read: true, can_create: true) }
    sign_in lender
    get loans_borrower_path(producer.person), headers: { "Turbo-Frame" => "borrower-card" }
    expect(card.text).to include(producer.person.full_name)
    expect(card.text).not_to include("Temporada")
  end

  it "is for who sees loans" do
    sign_in create(:user).tap { create(:permission, user: it, module_key: "trading", can_read: true) }

    get loans_borrower_path(create(:person, :client))

    expect(response).to redirect_to(root_path)
  end

  it "loads into the loan form, already with the person when the form has one" do
    person = create(:person, :client)
    sign_in admin

    get new_loans_loan_path
    expect(Nokogiri::HTML(response.body).at_css("turbo-frame#borrower-card")["src"]).to be_nil

    get new_loans_loan_path(person_id: person.id)
    expect(Nokogiri::HTML(response.body).at_css("turbo-frame#borrower-card")["src"]).to eq(loans_borrower_path(person))
  end
end
