require "rails_helper"

# Details with tabs (Fernando, 2026-10-18, as the producer's and the
# payroll's): they change in place, without asking the server.
RSpec.describe "Detail tabs", type: :system do
  let(:user) { create(:user, :admin) }
  let(:person) { create(:person, first_names: "Ana", last_names: "Zelaya") }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"

  before { sign_in_as(user) }

  it "splits an account into its loans and its history" do
    create(:loan_payment, loan: create(:loan, person:), amount: 100)
    visit loans_credit_account_path(person)
    mark_page

    expect(page).to have_css("#account-loans", visible: true)
    expect(page).to have_css("#account-history", visible: :hidden)
    click_button "Historial crediticio"
    expect(page).to have_css("#account-history", visible: true)
    expect(page).to have_css("#account-loans", visible: :hidden)
    expect(page_reloaded?).to be(false)
  end

  it "splits a carrero into purchases and payments, and a person into data and roles" do
    hauler = create(:hauler, person:)
    create(:producer, person:)
    visit trading_hauler_path(hauler)
    click_button "Pagos"
    expect(page).to have_css("#hauler-payments", visible: true, text: "Todavía no se le ha pagado.")

    visit administration_person_path(person)
    expect(page).to have_css("[role=tab]", count: 3)
    click_button "Carrero"
    expect(page).to have_css("#person-hauler", visible: true)
    expect(page).to have_css("#person-data", visible: :hidden)
  end
end
