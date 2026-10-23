require "rails_helper"

# Printing the promissory note and the loan contract of a loan (Fernando,
# 2026-10-22 and 23): a button per document on each loan, with its counter;
# the document opens filled in to check it, then prints.
RSpec.describe "Printing private documents" do
  let(:admin) { create(:user, :admin, name: "Fernando Admin") }
  let(:person) { create(:person, first_names: "Ana", last_names: "Zelaya", dni: "0801199912345") }
  let!(:loan) { create(:loan, person:, cash_amount: 1_500, monthly_interest_rate: 5) }
  let(:note) { PrivateDocument.fetch("promissory_note") }
  let(:contract) { PrivateDocument.fetch("loan_contract") }

  def lender(**flags) = create(:user, name: "Luis Prestamista").tap { create(:permission, user: it, module_key: "loans", can_read: true, **flags) }
  def page = Nokogiri::HTML(response.body)
  def buttons(loan) = page.at_css("tr#loan_#{loan.id}")
  def counter(loan, key) = page.at_css("tr#loan_#{loan.id} #loan-#{loan.id}-#{key} [data-print-count]")
  def preview_path(loan = self.loan, document: "promissory_note") = new_loans_credit_account_document_print_path(loan.person, document:, loan_id: loan.id)

  before do
    note.update!(body: %(<p>Yo, <span data-variable="person.full_name">x</span>, debo L <span data-variable="loan.amount">x</span>
                          (<span data-variable="loan.amount_in_words">x</span>), <span data-variable="person.civil_status">x</span>.</p>))
    contract.update!(body: %(<p>Contrato con <span data-variable="person.full_name">x</span></p>))
  end

  it "puts on each loan a button per document, which opens the document filled in, each with its counter" do
    older = create(:loan, person:, disbursed_on: Time.zone.today - 300, due_on: Time.zone.today - 200)
    create_list(:private_document_print, 2, person:, loan: older, private_document: note, user: admin)
    sign_in lender(can_create: true)

    get loans_credit_account_path(person)
    expect(buttons(older).css("a[aria-label^='Imprimir']").map { it["aria-label"] })
      .to eq([ "Imprimir Pagaré del préstamo #{older.id}", "Imprimir Contrato privado de préstamo del préstamo #{older.id}" ])
    expect(buttons(older).at_css("a[aria-label^='Imprimir Pagaré']")["href"]).to eq(preview_path(older))
    expect([ counter(older, "promissory_note"), counter(older, "loan_contract"), counter(loan, "promissory_note") ].map { it["data-print-count"] })
      .to eq(%w[2 0 0])
    expect(page.at_css("#card_loan_#{older.id}").text).to include("Pagaré", "Contrato")
    # No print buttons for the whole account any more, and no history for who is not an admin.
    expect(page.css("#account-documents-panel")).to be_empty
    expect(page.css(".print-count-card")).to be_empty

    get loans_loan_path(older)
    expect(page.css("a[aria-label^='Imprimir']").size).to eq(2)
    expect(page.at_css("#loan-#{older.id}-promissory_note [data-print-count]")["data-print-count"]).to eq("2")
  end

  it "shows admins the latest prints of each loan with their dates and users" do
    print = create(:private_document_print, person:, loan:, private_document: note, user: create(:user, name: "Marta Caja"))
    sign_in admin

    get loans_credit_account_path(person)
    card = page.at_css("tr#loan_#{loan.id} #loan-#{loan.id}-promissory_note .print-count-card")
    expect(card.text.squish).to include("Últimas impresiones: Pagaré", I18n.l(print.created_at, format: :default), "Marta Caja")
    expect(card.at_css("a")["href"]).to eq(loans_credit_account_document_print_path(person, print))
  end

  it "counts the prints for everyone who sees the loans, with no buttons for who cannot print" do
    create(:private_document_print, person:, loan:, private_document: contract, user: admin)
    sign_in lender

    get loans_credit_account_path(person)
    expect(buttons(loan).css("a[aria-label^='Imprimir']")).to be_empty
    expect(buttons(loan).at_css("#loan-#{loan.id}-loan_contract [aria-label^='Impreso']")["aria-label"]).to eq("Impreso 1 vez")

    get preview_path
    expect(response).to redirect_to(root_path)
    expect { post loans_credit_account_document_prints_path(person), params: { private_document_print: { document_key: "promissory_note", loan_id: loan.id } } }
      .not_to change(PrivateDocumentPrint, :count)
  end

  it "shows the document filled in before printing, with what will print blank and the way to complete it" do
    sign_in admin
    expect { get preview_path }.not_to change(PrivateDocumentPrint, :count)
    expect(response).to have_http_status(:ok)
    expect(page.at_css(".document-sheet .document-body").text.squish)
      .to eq("Yo, Ana Zelaya, debo L 1,500.00 (mil quinientos lempiras exactos), #{PrivateDocumentVariables::BLANK}.")
    missing = page.at_css("#document-missing")
    expect(missing.text).to include("Estado civil")
    expect(missing.at_css("a")["href"]).to eq(edit_administration_person_path(person))
    expect(missing.at_css("a")["data-turbo-frame"]).to eq("modal")

    # Completed, the page fills in again.
    person.update!(civil_status: "casada")
    get preview_path
    expect(page.at_css(".document-body").text).to include("casada")
    expect(page.at_css("#document-missing")).to be_nil
  end

  it "offers completing the person only to who can edit people" do
    sign_in lender(can_create: true)
    get preview_path
    expect(page.at_css("#document-missing").text).to include("Estado civil")
    expect(page.at_css("#document-missing a")).to be_nil
  end

  it "records the print, filled in, and opens it to print" do
    user = lender(can_create: true)
    sign_in user
    expect {
      post loans_credit_account_document_prints_path(person), params: { private_document_print: { document_key: "promissory_note", loan_id: loan.id } }
    }.to change(PrivateDocumentPrint, :count).by(1)

    print = PrivateDocumentPrint.last
    expect(response).to redirect_to(loans_credit_account_document_print_path(person, print, print: 1))
    expect([ print.person, print.loan, print.user, print.private_document ]).to eq([ person, loan, user, note ])

    follow_redirect!
    sheet = page.at_css(".document-sheet")
    expect(sheet.at_css("header.border-b-2").text).to include("Pagaré", "Ana Zelaya")
    expect(sheet.at_css(".document-body").text.squish)
      .to eq("Yo, Ana Zelaya, debo L 1,500.00 (mil quinientos lempiras exactos), #{PrivateDocumentVariables::BLANK}.")
    expect(page.at_css("[data-controller='print']")["data-print-auto-value"]).to eq("true")

    get loans_loan_path(loan)
    expect(page.at_css("#loan-#{loan.id}-promissory_note [data-print-count]")["data-print-count"]).to eq("1")
  end

  it "does not take a loan of someone else, no loan, nor a document that does not exist" do
    sign_in admin
    expect {
      post loans_credit_account_document_prints_path(person), params: { private_document_print: { document_key: "promissory_note", loan_id: create(:loan).id } }
      post loans_credit_account_document_prints_path(person), params: { private_document_print: { document_key: "promissory_note", loan_id: "" } }
      post loans_credit_account_document_prints_path(person), params: { private_document_print: { document_key: "invoice", loan_id: loan.id } }
    }.not_to change(PrivateDocumentPrint, :count)
    get new_loans_credit_account_document_print_path(person, document: "promissory_note", loan_id: create(:loan).id)
    expect(response).to redirect_to(root_path)
  end

  it "disables the buttons of a document without text" do
    contract.update!(body: "")
    sign_in admin
    get loans_credit_account_path(person)
    expect(buttons(loan).at_css("#loan-#{loan.id}-loan_contract button[disabled]").text.squish).to eq("Contrato")

    post loans_credit_account_document_prints_path(person), params: { private_document_print: { document_key: "loan_contract", loan_id: loan.id } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("todavía no tiene texto")
  end

  it "opens the producer from the account of a producer, for who sees Compra de café" do
    producer = create(:producer, person:)
    user = lender
    sign_in user
    get loans_credit_account_path(person)
    expect(page.css("a").map { it.text.squish }).not_to include("Ver productor")

    create(:permission, user:, module_key: "trading", can_read: true)
    get loans_credit_account_path(person)
    expect(page.css("a").find { it.text.squish == "Ver productor" }["href"]).to eq(trading_producer_path(producer))

    get loans_credit_account_path(create(:loan).person)
    expect(page.css("a").map { it.text.squish }).not_to include("Ver productor")
  end
end
