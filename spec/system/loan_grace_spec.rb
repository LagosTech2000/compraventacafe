require "rails_helper"

# A loan of the intermediary type skips the interest of its first 10 days
# (Fernando, 2026-10-24), for anyone: the box is always in the form.
RSpec.describe "Loan of the intermediary type", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "offers the 10 days without interest to any person" do
    client = create(:person, :client, first_names: "Rosa", last_names: "Díaz")
    visit new_loans_loan_path
    label = "Préstamo tipo intermediario: los primeros 10 días no generan interés"
    expect(page).to have_field(label, checked: false)

    pick_record "person_search", client.picker_label
    check label
    fill_in "loan_cash_amount", with: "1000"
    fill_in "loan_monthly_interest_rate", with: "3"
    fill_in "loan_term_days", with: "30"
    find("main form [type=submit]").click
    expect(page).to have_text("Tipo intermediario: los primeros 10 días sin interés")
    expect(Loan.last).to have_attributes(person: client, interest_grace: true)
  end
end
