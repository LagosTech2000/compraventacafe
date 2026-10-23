require "rails_helper"

# The documents' rich text editor (Jodit) with its variables, and printing
# them from a credit account with the counter of prints (Fernando,
# 2026-10-22).
RSpec.describe "Private documents", type: :system do
  let(:admin) { create(:user, :admin, name: "Fernando Admin") }
  let(:person) { create(:person, :client, first_names: "Ana", last_names: "Zelaya") }
  let(:note) { PrivateDocument.fetch("promissory_note") }

  # window.print() would wait for a printer: it counts instead.
  def stub_print
    page.driver.browser.page.command("Page.addScriptToEvaluateOnNewDocument",
                                     source: "window.print = () => { window.printed = (window.printed || 0) + 1 }")
  end

  before { sign_in_as(admin) }

  it "edits a document with the rich text editor and puts a variable where the cursor is" do
    note.update!(body: "<p>Yo, </p>")
    visit administration_private_document_path(note)
    click_on "Editar" # a Turbo visit: the editor's script and stylesheet come with it
    editor = find(".jodit-wysiwyg.document-body")
    expect(page).to have_css("head link[href*='jodit']", visible: :all)
    expect(page).to have_css(".jodit-toolbar__box")

    editor.click
    page.execute_script(<<~JS)
      const paragraph = document.querySelector(".jodit-wysiwyg p")
      const range = document.createRange()
      range.selectNodeContents(paragraph)
      range.collapse(false)
      getSelection().removeAllRanges()
      getSelection().addRange(range)
    JS
    within("aside") { click_on "Nombre completo" }
    expect(editor).to have_css("span[data-variable='person.full_name'][contenteditable='false']", text: "[Nombre completo]")
    expect(page).to have_css("form[data-controller~='document-editor'][data-dirty='true']")

    click_on "Guardar"
    expect(page).to have_css(".toast-region .toast", text: "Se guardó «Pagaré».")
    expect(note.reload.body).to eq(%(<p>Yo, <span data-variable="person.full_name">[Nombre completo]</span></p>))
    expect(find(".document-sheet")).to have_css("span[data-variable]", text: "[Nombre completo]")
  end

  it "prints a loan's document after checking it, completing the person there; admins see when and by whom over the counter" do
    note.update!(body: %(<p>Yo, <span data-variable="person.full_name">x</span>, <span data-variable="person.civil_status">x</span>.</p>))
    loan = create(:loan, person:)
    stub_print
    visit loans_credit_account_path(person)
    expect(find("tr#loan_#{loan.id} #loan-#{loan.id}-promissory_note .print-count-number")).to have_text("0")

    find("tr#loan_#{loan.id} a[aria-label^='Imprimir Pagaré']").click
    expect(find(".document-sheet .document-body")).to have_text("Yo, Ana Zelaya, #{PrivateDocumentVariables::BLANK}.")
    expect(PrivateDocumentPrint.count).to eq(0)

    # The person's form opens on top; saved, the document fills in again.
    within("#document-missing") { click_on "Completar datos de la persona" }
    within("dialog[open]") do
      fill_in "Estado civil", with: "casada"
      click_on "Guardar"
    end
    expect(find(".document-sheet .document-body")).to have_text("Yo, Ana Zelaya, casada.")
    expect(page).to have_no_css("#document-missing")

    click_on "Imprimir"
    expect(page).to have_current_path(loans_credit_account_document_print_path(person, PrivateDocumentPrint.last)) # ?print=1 left
    page.document.synchronize { raise Capybara::ExpectationNotMet, "not printed" unless page.evaluate_script("window.printed") == 1 }

    click_on "Volver al préstamo"
    counter = find("#loan-#{loan.id}-promissory_note .print-count")
    expect(counter).to have_css(".print-count-number", text: "1")
    expect(page).to have_no_css(".print-count-card", visible: :visible)
    counter.hover
    expect(page).to have_css(".print-count-card", visible: :visible, text: "Fernando Admin")
  end
end
