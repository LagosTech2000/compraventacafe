require "rails_helper"

# Merging people from Administración (Fernando, 2026-10-14): administrators only.
RSpec.describe "Administración: fusionar personas" do
  let(:admin) { create(:user, :admin) }
  let(:primary) { create(:person, :client, first_names: "Ana María", last_names: "Zelaya") }
  let(:secondary) { create(:person, :client, first_names: "Ana Maria", last_names: "Zelaya", dni: "0801199912345") }

  def page = Nokogiri::HTML(response.body)

  it "compares the two, field by field, and merges the other one into the one kept" do
    sign_in admin
    get administration_person_path(primary)
    expect(page.at_css("a[href='#{new_administration_person_merge_path(primary)}']")).to be_present

    get new_administration_person_merge_path(primary, other_id: secondary.id)
    rows = page.css("[id^=merge-field-]").to_h { |row| [ row["id"].delete_prefix("merge-field-"), row ] }
    expect(rows.keys).to eq(%w[first_names dni])
    expect(rows["dni"].at_css("input[value=secondary]")["checked"]).to eq("checked")
    expect(page.text).to include("Queda", "Se fusiona y se borra", "Sin compras")

    post administration_person_merge_path(primary), params: { other_id: secondary.id, keep: "this",
                                                                choices: { first_names: "secondary", dni: "secondary" } }
    expect(response).to redirect_to(administration_person_path(primary))
    expect(flash[:notice]).to eq("Ana Maria Zelaya se fusionó en Ana Maria Zelaya.")
    expect(primary.reload).to have_attributes(first_names: "Ana Maria", dni: "0801199912345")
    expect(Person.exists?(secondary.id)).to be(false)

    get administration_audit_event_path(AuditEvent.find_by!(action: "merge"))
    expect(page.text.squish).to include("Fusionó personas", "Detalle de la fusión", "Persona fusionada (se borró)")
  end

  it "keeps the other one when asked" do
    sign_in admin
    post administration_person_merge_path(primary), params: { other_id: secondary.id, keep: "other" }
    expect(response).to redirect_to(administration_person_path(secondary))
    expect(Person.exists?(primary.id)).to be(false)
  end

  it "says why two people in the same payroll cannot be merged, without the button" do
    payroll = create(:payroll, name: "Limpia")
    [ primary, secondary ].each do |person|
      create(:collaborator, person:)
      create(:payroll_member, payroll:, person:)
    end
    sign_in admin
    get new_administration_person_merge_path(primary, other_id: secondary.id)
    expect(page.text).to include("planilla Limpia")
    expect(page.css("form[action='#{administration_person_merge_path(primary)}'] [type=submit]")).to be_empty
    post administration_person_merge_path(primary), params: { other_id: secondary.id }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Person.exists?(secondary.id)).to be(true)
  end

  it "is only for administrators, even with every Administración permission" do
    user = create(:user).tap { |u| create(:permission, user: u, module_key: "administration", can_read: true, can_create: true, can_update: true, can_destroy: true) }
    sign_in user
    get administration_person_path(primary)
    expect(page.at_css("a[href='#{new_administration_person_merge_path(primary)}']")).to be_nil
    get new_administration_person_merge_path(primary)
    expect(response).to redirect_to(root_path)
    post administration_person_merge_path(primary), params: { other_id: secondary.id }
    expect(Person.exists?(secondary.id)).to be(true)
  end
end
