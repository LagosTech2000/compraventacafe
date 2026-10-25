require "rails_helper"

# An intermediary's loan can skip the interest of its first 10 days
# (Fernando, 2026-10-24): the box only shows for one (loan_grace_controller.js).
RSpec.describe "Loan grace for intermediaries", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "offers the 10 days without interest only when the person is an intermediary" do
    client = create(:person, :client, first_names: "Rosa", last_names: "Díaz")
    intermediary = create(:producer, kind: "intermediary", person: create(:person, first_names: "Mario", last_names: "Reyes")).person
    visit new_loans_loan_path
    label = "Intermediario: los primeros 10 días no generan interés"
    expect(page).to have_no_field(label)

    pick_record "person_search", client.picker_label
    expect(page).to have_no_field(label)

    pick_record "person_search", intermediary.picker_label
    check label
    fill_in "loan_cash_amount", with: "1000"
    fill_in "loan_monthly_interest_rate", with: "3"
    fill_in "loan_term_days", with: "30"
    find("main form [type=submit]").click
    expect(page).to have_text("los primeros 10 días sin interés")
    expect(Loan.last).to have_attributes(person: intermediary, interest_grace: true)
  end
end
