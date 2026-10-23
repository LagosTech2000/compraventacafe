require "rails_helper"

# Lists of people show each one's photo or initials before the name
# (Fernando, 2026-10-18: as the details do). The initials are drawn by CSS,
# so the cell's text stays the name.
RSpec.describe "Photos in lists" do
  let(:person) { create(:person, first_names: "Ana", last_names: "Zelaya") }

  before { sign_in create(:user, :admin) }

  it "puts the initials before the name in people, producers, loans and accounts" do
    create(:producer, person:)
    create(:loan, person:)

    [ administration_people_path, trading_producers_path, loans_loans_path, loans_credit_accounts_path ].each do |path|
      get path
      cell = Nokogiri::HTML(response.body).css("tbody td").find { it.text.strip == "Ana Zelaya" }
      expect(cell).to be_present, path
      expect(cell.at_css(".avatar-initials")["data-initials"]).to eq("AZ")
    end
  end
end
