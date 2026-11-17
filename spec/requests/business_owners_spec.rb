require "rails_helper"

# The owners of the business (Fernando, 2026-11-16): only an administrator
# marks them; picked as the producer of a purchase, an owner can name the
# business's farms too (all owners share them), and it is a normal purchase.
RSpec.describe "Business owners" do
  let(:admin) { create(:user, :admin) }
  let(:owner) { create(:producer, person: create(:person, first_names: "David", last_names: "Espinal", business_owner: true)) }
  let(:other) { create(:producer) }
  let!(:business_farm) { create(:farm, name: "Niebla Dorada", producer: nil) }

  def page = Nokogiri::HTML(response.body)

  it "is marked only by an administrator" do
    person = create(:person, :client)
    editor = create(:user).tap { create(:permission, user: it, module_key: "administration", can_read: true, can_update: true) }
    sign_in editor
    get edit_administration_person_path(person)
    expect(page.at_css("input[name='person[business_owner]']")).to be_nil
    patch administration_person_path(person), params: { person: { business_owner: "1", client_role: "1" } }
    expect(person.reload.business_owner).to be(false)

    sign_in admin
    patch administration_person_path(person), params: { person: { business_owner: "1", client_role: "1" } }
    expect(person.reload.business_owner).to be(true)
    get administration_person_path(person)
    expect(page.at_css("[data-business-owner]").text).to eq("Dueño del negocio")
  end

  it "lets an owner's purchase name the business's farms, and nobody else's" do
    own = create(:farm, name: "Su finca", producer: owner)
    expect(PickerSearch.data(owner)[:farms].map { it[0..1] }).to eq([ [ own.id, "Su finca" ], [ business_farm.id, "Niebla Dorada · del negocio" ] ])
    expect(PickerSearch.data(other)[:farms]).to be_empty

    expect(build(:purchase, producer: owner, farm: business_farm)).to be_valid
    stranger = build(:purchase, producer: other, farm: business_farm)
    expect(stranger).not_to be_valid
    expect(stranger.errors[:farm]).to be_present

    sign_in admin
    get new_trading_purchase_path(producer_id: owner.id)
    expect(page.css("select[name='purchase[farm_id]'] option").map(&:text)).to include("Niebla Dorada · del negocio")
  end
end
