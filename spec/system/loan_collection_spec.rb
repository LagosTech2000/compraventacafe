require "rails_helper"

# The loans module's collection screens answer inside their frame, without
# reloading the page (Fernando, 2026-11-03).
RSpec.describe "Loan collection screens", type: :system do
  let(:user) { create(:user, :admin) }
  let(:today) { Time.zone.today }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"

  before { sign_in_as(user) }

  it "switches the week of the collection calendar in place, and the URL follows" do
    create(:loan, person: create(:person, first_names: "Ana", last_names: "Zelaya"), due_on: today - 2)
    create(:loan, person: create(:person, first_names: "Luis", last_names: "Mejía"), due_on: today.beginning_of_week + 9)

    visit loans_collection_calendar_path
    mark_page
    expect(page).to have_css("#collection-calendar", text: "Ana Zelaya")

    week = (today.beginning_of_week + 7).iso8601
    find("#calendar-bucket-#{week}").click
    expect(page).to have_css("#collection-calendar", text: "Luis Mejía")
    expect(page).to have_no_css("#collection-calendar tbody", text: "Ana Zelaya")
    expect(page).to have_current_path(/week=#{week}/)
    expect(page_reloaded?).to be(false)
  end

  it "calculates the simulation as the fields change, without reloading" do
    visit loans_simulation_path
    mark_page

    fill_in "Monto a prestar", with: "10000"
    fill_in "Tasa de interés mensual (%)", with: "3"
    fill_in "Días", with: "30"
    find_field("Días").send_keys(:tab)

    expect(page).to have_css("#simulation-result", text: "L 10,300.00")
    expect(page_reloaded?).to be(false)

    check "Tipo intermediario: los primeros 10 días no generan interés"
    expect(page).to have_css("#simulation-result", text: "L 10,200.00")
    expect(page_reloaded?).to be(false)
  end

  it "pays with coffee from Cobrar con café and the list follows" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0)
    purchase = create(:purchase, producer:)

    visit loans_coffee_collection_path
    within("#coffee-collection-list") { first(:link, "Abonar con café").click }
    within("dialog[open]") do
      find("input[name^='purchase_loan_settlement[amounts]']").set("1000")
      click_button "Registrar abonos"
    end

    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_css("#coffee-collection-list", text: "Nadie que deba")
    expect(purchase.loan_payments.sum(:amount)).to eq(1_000)
  end
end
