require "rails_helper"

RSpec.describe PrivateDocumentPrint do
  include ActiveSupport::Testing::TimeHelpers

  let(:person) { create(:person, first_names: "Ana", last_names: "Zelaya") }

  it "keeps the document as it printed, even if the text or the person change later" do
    print = create(:private_document_print, person:)
    expect(print.body).to eq("<p>Pagaré de Ana Zelaya</p>")

    print.private_document.update!(body: "<p>Otro texto</p>")
    person.update!(first_names: "Ana María")
    expect(print.reload.body).to eq("<p>Pagaré de Ana Zelaya</p>")
  end

  it "does not print a document without text, nor a loan of someone else" do
    contract = PrivateDocument.fetch("loan_contract")
    contract.update!(body: "")
    print = described_class.new(private_document: contract, person:, user: create(:user))
    expect(print).not_to be_valid
    expect(print.errors[:base].join).to include("todavía no tiene texto")

    print = build(:private_document_print, person:, loan: create(:loan))
    expect(print).not_to be_valid
    expect(print.errors[:loan]).to include("no es de esta persona")
  end

  it "counts the prints of each document per loan and keeps the latest ones with their users" do
    loan = create(:loan, person:)
    other_loan = create(:loan, person:)
    note = create(:private_document_print, person:, loan:).private_document
    contract = PrivateDocument.fetch("loan_contract").tap { it.update!(body: "<p>Contrato</p>") }
    travel_to(1.day.ago) { create_list(:private_document_print, 11, person:, loan:, private_document: note) }
    create(:private_document_print, person:, loan:, private_document: contract)
    create(:private_document_print, person:, loan: other_loan, private_document: note)

    expect(described_class.counts_by_loan([ loan.id ])).to eq([ loan.id, note.id ] => 12, [ loan.id, contract.id ] => 1)
    history = described_class.history_by_loan([ loan.id, other_loan.id ])
    expect(history[[ loan.id, note.id ]].size).to eq(PrivateDocumentPrint::HISTORY_SIZE)
    expect(history[[ loan.id, note.id ]].first.created_at).to be > 1.hour.ago
    expect(history[[ other_loan.id, note.id ]].size).to eq(1)

    prints = LoanDocumentPrints.new([ loan, other_loan ])
    expect([ prints.count(loan, note), prints.count(other_loan, note), prints.count(other_loan, contract) ]).to eq([ 12, 1, 0 ])
    expect(prints.history(loan, note)).to eq([])
  end

  it "is audited without the printed text" do
    print = create(:private_document_print, person:)
    event = AuditEvent.where(auditable: print).sole
    expect(event.changeset.keys).not_to include("body")
    expect(event.auditable_label).to eq("Pagaré · Ana Zelaya")
  end
end
