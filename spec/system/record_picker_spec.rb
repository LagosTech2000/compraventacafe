require "rails_helper"

# Searchable pickers (record_picker_controller.js): from 3 characters the
# page asks the server and shows the matches under the box.
RSpec.describe "Searchable picker", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "asks for 3 characters, shows the matches and chooses one with the arrows and Enter" do
    ana = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:producer, person: create(:person, first_names: "Luis", last_names: "Zelaya"))
    ana.farms.create!(name: "El Mirador")
    visit new_trading_purchase_path

    # Typed key by key, as a person does (the box keeps the focus).
    box = find_field("producer_search")
    box.send_keys("Ze")
    expect(page).to have_css("#producer_search_matches", text: "Escribe al menos 3 letras o números para buscar.")

    box.send_keys("la")
    within("#producer_search_matches") do
      expect(page).to have_css("[role=option]", count: 2)
      expect(page).to have_css("[role=option]", text: "Ana Zelaya")
    end
    box.send_keys(:down, :enter)

    expect(page).to have_field("producer_search", with: "Ana Zelaya")
    expect(page).to have_css("#producer_search_matches", visible: :hidden)
    expect(page).to have_select("purchase_farm_id", options: [ "Sin finca asignada", "El Mirador" ])
  end

  it "chooses a match with a click, and says when there is none" do
    create(:person, :client, first_names: "Rosa", last_names: "Mejía")
    visit new_loans_loan_path

    box = find_field("person_search")
    box.send_keys("xyz")
    expect(page).to have_css("#person_search_matches", text: "No se encontró a nadie con ese nombre o número.")

    box.send_keys(*Array.new(3, :backspace), "mejia")
    find("#person_search_matches [role=option]", text: "Rosa Mejía").click
    expect(page).to have_field("person_search", with: "Rosa Mejía")
    within("turbo-frame#borrower-card") { expect(page).to have_text("Rosa Mejía") }
  end

  it "forgets the record chosen when the text changes" do
    create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    visit new_trading_purchase_path
    pick_record "producer_search", "Ana Zelaya"

    find_field("producer_search").send_keys(:backspace)
    expect(page).to have_css("#producer_search:invalid")
    expect(page).to have_text("Elige primero el productor")
    # Its search answers before the spec ends (no request left behind).
    expect(page).to have_css("#producer_search_matches [role=option]", text: "Ana Zelaya")
  end
end
