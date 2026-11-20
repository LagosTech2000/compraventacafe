require "rails_helper"

# The notice of people already registered (Fernando, 2026-11-18): for who
# writes people (Personas, producers, haulers).
RSpec.describe "Person duplicates" do
  let!(:ana) { create(:person, first_names: "Ana", last_names: "Zelaya", phone: "99990000") }

  def page = Nokogiri::HTML(response.body)

  it "lists who looks alike, with why, in its frame" do
    sign_in create(:user, :admin)
    get person_duplicates_path(first_names: "ana", last_names: "zelaya", phone: "9999-0000")
    row = page.at_css("turbo-frame#person-duplicates #duplicate_person_#{ana.id}")
    expect(row.text).to include("Ana Zelaya", "mismo teléfono y mismos nombres", "Ver")

    get person_duplicates_path(first_names: "Luis", last_names: "Pérez")
    expect(page.at_css("turbo-frame#person-duplicates [data-person-duplicates]")).to be_nil
  end

  it "is for who writes people, and the forms carry it only for them" do
    clerk = create(:user).tap { create(:permission, user: it, module_key: "trading", submodule_key: "producers", can_read: true, can_create: true) }
    sign_in clerk
    get person_duplicates_path(first_names: "Ana", last_names: "Zelaya")
    expect(page.at_css("[data-person-duplicates]").text).not_to include("Ver")
    get new_trading_producer_path
    expect(page.at_css("[data-controller~='person-duplicates'] turbo-frame#person-duplicates")).to be_present

    sign_in create(:user).tap { create(:permission, user: it, module_key: "loans", can_read: true) }
    get person_duplicates_path(first_names: "Ana", last_names: "Zelaya")
    expect(response).to redirect_to(root_path)
  end
end
