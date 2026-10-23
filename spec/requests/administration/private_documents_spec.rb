require "rails_helper"

RSpec.describe "Private documents" do
  let(:admin) { create(:user, :admin) }
  let(:note) { PrivateDocument.fetch("promissory_note") }

  def page = Nokogiri::HTML(response.body)

  it "lists the two documents with a preview, and opens each one" do
    note.update!(body: %(<p><strong>PAGARÉ</strong> de <span data-variable="person.full_name">x</span></p>))
    sign_in admin

    get administration_private_documents_path
    expect(response).to have_http_status(:ok)
    expect(page.css("article h2").map(&:text)).to eq([ "Pagaré", "Contrato privado de préstamo" ])
    expect(page.at_css("#private_document_#{note.id} .document-thumb").text).to include("PAGARÉ de [Nombre completo]")
    expect(page.at_css("#private_document_#{PrivateDocument.fetch("loan_contract").id}").text).to include("Todavía no tiene texto")
    expect(page.css("nav a").map(&:text)).to include("Documentos privados")

    get administration_private_document_path(note)
    expect(page.at_css(".document-sheet").text).to include("PAGARÉ de [Nombre completo]")
    expect(page.at_css("aside").text).to include("Nombre completo")
  end

  it "saves the text, cleaned, and records who changed it" do
    sign_in admin
    get edit_administration_private_document_path(note)
    expect(response).to have_http_status(:ok)
    expect(page.css("[data-variable-key]").size).to eq(PrivateDocumentVariables::KEYS.size)

    patch administration_private_document_path(note), params: { private_document: {
      body: %(<p style="text-align: center;">Yo, <span data-variable="person.dni" contenteditable="false">x</span></p><script>x()</script>),
      lock_version: note.lock_version
    } }
    expect(response).to redirect_to(administration_private_document_path(note))
    expect(note.reload.body).to eq(%(<p style="text-align:center;">Yo, <span data-variable="person.dni">[DNI]</span></p>x()))
    expect(note.updated_by).to eq(admin)
    expect(AuditEvent.where(auditable: note, action: "update").sole.user).to eq(admin)
  end

  it "does not save over a newer change" do
    sign_in admin
    stale = note.lock_version
    note.update!(body: "<p>Nuevo</p>")
    patch administration_private_document_path(note), params: { private_document: { body: "<p>Viejo</p>", lock_version: stale } }
    expect(note.reload.body).to eq("<p>Nuevo</p>")
  end

  it "is only for admins, and there is no adding or removing a document" do
    manager = create(:user).tap { create(:permission, user: it, module_key: "administration", can_read: true, can_update: true) }
    sign_in manager
    get administration_private_documents_path
    expect(response).to redirect_to(root_path)
    patch administration_private_document_path(note), params: { private_document: { body: "<p>x</p>" } }
    expect(note.reload.body).not_to eq("<p>x</p>")

    expect(Rails.application.routes.recognize_path("/administration/private_documents", method: :post)[:action]).to eq("not_found")
    expect(Rails.application.routes.recognize_path("/administration/private_documents/promissory_note", method: :delete)[:action]).to eq("not_found")
  end
end
