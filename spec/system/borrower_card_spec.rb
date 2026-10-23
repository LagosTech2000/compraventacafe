require "rails_helper"

# The loan form's card (record_card_controller.js): it follows the person
# picked and goes back to the hint when the field is emptied.
RSpec.describe "Borrower card on the loan form", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "shows the card of the person picked, and the hint again when emptied" do
    rosa = create(:person, :client, first_names: "Rosa", last_names: "Díaz")
    create(:loan, person: rosa, cash_amount: 2_000, monthly_interest_rate: 0)
    luis = create(:person, :collaborator, first_names: "Luis", last_names: "Mejía")
    visit new_loans_loan_path

    expect(page).to have_text("¿A quién se le presta?")
    # Wide: the card fills the column on the right of the fields.
    left = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().left") }
    expect(left.("main aside")).to be > left.("#person_search") + 500

    pick_record "person_search", rosa.picker_label
    within("turbo-frame#borrower-card") { expect(page).to have_text("Rosa Díaz").and have_text("L 2,000.00") }

    pick_record "person_search", luis.picker_label
    within("turbo-frame#borrower-card") { expect(page).to have_text("Luis Mejía").and have_text("Sería su primer préstamo") }

    # Erased with the keyboard (fill_in with "" sends no input event).
    find_field("person_search").send_keys(*Array.new(luis.picker_label.length, :backspace))
    expect(page).to have_text("¿A quién se le presta?")
    within("turbo-frame#borrower-card") { expect(page).to have_no_text("Luis Mejía") }
  end

  it "keeps the form and the card inside the screen on a phone" do
    person = create(:person, :client, first_names: "Ana María", last_names: "Zelaya Hernández", dni: "0801199912345",
                                      email: "ana.maria.zelaya.hernandez@example.com")
    page.driver.resize(390, 1600)
    visit new_loans_loan_path(person_id: person.id)
    within("turbo-frame#borrower-card") { expect(page).to have_text("Ana María Zelaya Hernández") }

    widths = page.evaluate_script(<<~JS)
      (() => { const form = document.querySelector("main form");
               return [document.documentElement.scrollWidth, window.innerWidth, form.scrollWidth, form.clientWidth] })()
    JS
    expect(widths[0]).to be <= widths[1]
    expect(widths[2]).to be <= widths[3]
  end
end
