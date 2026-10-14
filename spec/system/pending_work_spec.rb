require "rails_helper"

# The pending work in the modal or the drawer: one tab per kind (Fernando,
# 2026-10-13). Changing tabs stays in the window; it never loads the home
# page inside it.
RSpec.describe "Pending work", type: :system do
  let(:user) { create(:user, :admin, window_style: "drawer") }
  let(:today) { Time.zone.today }

  it "shows each kind of work in its own tab, inside the drawer" do
    create(:purchase, producer: create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")))
    loan = create(:loan, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: today - 90, due_on: today - 5)
    sign_in_as(user)
    click_link "Ver el detalle"
    drawer = wait_for_drawer

    within(drawer) do
      expect(page).to have_css("[role=tab][aria-selected=true]", text: "Compras sin facturar")
      expect(page).to have_text("Ana Zelaya")
      expect(page).to have_no_text("Préstamo #{loan.id}")

      find("[role=tab]", text: "Préstamos vencidos").click
      expect(page).to have_css("[role=tab][aria-selected=true]", text: "Préstamos vencidos")
      expect(page).to have_text("Préstamo #{loan.id}")
      expect(page).to have_no_text("Ana Zelaya")
      expect(page).to have_css("h1", text: "Tareas pendientes") # not the home page
      expect(page).to have_no_css("h1", text: "Hola,")

      find("[role=tab]", text: "Préstamos vencidos").send_keys(:left) # the arrow keys move between tabs
      expect(page).to have_css("[role=tab][aria-selected=true]", text: "Compras sin facturar")
      expect(page).to have_text("Ana Zelaya")
    end
  end
end
