require "rails_helper"

RSpec.describe PrivateDocument do
  let(:note) { described_class.fetch("promissory_note") }

  it "is always the promissory note and the loan contract, created when missing" do
    described_class.delete_all
    expect(described_class.ordered.map(&:key)).to eq(%w[promissory_note loan_contract])
    described_class.ensure_all!
    expect(described_class.count).to eq(2)
    expect(described_class.new(key: "invoice")).not_to be_valid
  end

  it "keeps the formatting and the variables, and nothing that runs" do
    note.update!(body: <<~HTML)
      <p style="text-align: justify;" onclick="steal()"><strong>Yo,</strong>
        <span data-variable="person.full_name" contenteditable="false" class="x">anything</span>
        <span data-variable="person.password">[?]</span></p>
      <table style="border-collapse: collapse;"><tbody><tr><td style="border: 1px solid #000;" colspan="2">Firma</td></tr></tbody></table>
      <script>alert(1)</script><img src="x" onerror="alert(1)"><a href="javascript:alert(1)">link</a>
    HTML

    html = note.reload.body
    expect(html).to include(%(<p style="text-align:justify;">), "<strong>Yo,</strong>", %(<td style="border:1px solid #000;" colspan="2">))
    expect(html).to include(%(<span data-variable="person.full_name">[Nombre completo]</span>))
    expect(html).not_to include("onclick", "contenteditable", "<script", "<img", "<a ", "javascript:", "person.password")
    expect(note.variable_keys).to eq(%w[person.full_name])
  end

  it "knows when it has no text yet" do
    expect(described_class.new(body: "<p><br></p> <p> </p>")).to be_blank_body
    expect(described_class.new(body: %(<p><span data-variable="today.date">x</span></p>))).not_to be_blank_body
  end

  it "fills its variables in for a person and one of their loans, with blank lines for what is missing" do
    person = create(:person, first_names: "Ana", last_names: "Zelaya", dni: "0801199912345", address_line: "<b>Barrio</b> El Centro")
    loan = create(:loan, person:, cash_amount: 1_500, monthly_interest_rate: 5, disbursed_on: Date.new(2026, 9, 1), due_on: Date.new(2026, 11, 30))
    note.update!(body: %w[person.full_name person.dni person.address person.civil_status loan.amount loan.amount_in_words loan.due_on
                          loan.term].map { |key| %(<p><span data-variable="#{key}">x</span></p>) }.join)

    html = note.filled_body(person:, loan:)
    expect(html).to include("<p>Ana Zelaya</p>", "<p>0801-1999-12345</p>", "<p>1,500.00</p>", "<p>mil quinientos lempiras exactos</p>",
                            "<p>30/11/2026</p>", "<p>90 días</p>", "<p>#{PrivateDocumentVariables::BLANK}</p>")
    expect(html).to include("&lt;b&gt;Barrio&lt;/b&gt; El Centro") # a value is text, never HTML
    expect(html).not_to include("data-variable")

    without_loan = note.filled_body(person:)
    expect(without_loan).to include("<p>Ana Zelaya</p>")
    expect(without_loan.scan(PrivateDocumentVariables::BLANK).size).to eq(5)
  end
end
