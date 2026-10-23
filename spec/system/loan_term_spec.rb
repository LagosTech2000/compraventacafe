require "rails_helper"

# The loan form's term in days (loan_term_controller.js): it fills the due
# date, follows it, and moves it with the loan's date. Only the dates are sent.
RSpec.describe "Loan term in days", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  def set_date(field, date) = find_field(field).execute_script("this.value = arguments[0]; this.dispatchEvent(new Event('change', { bubbles: true }))", date)

  it "fills the due date from the days and the days from the due date" do
    person = create(:person, :client, first_names: "Rosa", last_names: "Díaz")
    visit new_loans_loan_path

    set_date("loan_disbursed_on", "2026-10-12")
    fill_in "loan_term_days", with: "90"
    expect(page).to have_field("loan_due_on", with: "2027-01-10")

    set_date("loan_due_on", "2026-11-11")
    expect(page).to have_field("loan_term_days", with: "30")

    set_date("loan_disbursed_on", "2026-10-22")
    expect(page).to have_field("loan_due_on", with: "2026-11-21")

    pick_record "person_search", person.picker_label
    fill_in "loan_cash_amount", with: "1000"
    fill_in "loan_monthly_interest_rate", with: "2"
    find("main form [type=submit]").click
    expect(page).to have_text("Plazo")
    expect(Loan.last).to have_attributes(disbursed_on: Date.new(2026, 10, 22), due_on: Date.new(2026, 11, 21), term_days: 30)
    expect(page).to have_text("30 días")
  end

  it "shows the days of a loan being edited" do
    loan = create(:loan, disbursed_on: Date.new(2026, 9, 1), due_on: Date.new(2026, 12, 1))
    visit edit_loans_loan_path(loan)
    expect(page).to have_field("loan_term_days", with: "91")
  end
end
