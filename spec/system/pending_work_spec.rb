require "rails_helper"

# The pending work in the modal or the drawer: every kind one below the
# other (Fernando, 2026-11-13; before, one tab per kind). It never loads the
# home page inside it.
RSpec.describe "Pending work", type: :system do
  let(:user) { create(:user, :admin, window_style: "drawer") }
  let(:today) { Time.zone.today }

  it "shows every kind of work one below the other, inside the drawer" do
    create(:purchase, producer: create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")))
    loan = create(:loan, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: today - 90, due_on: today - 5)
    sign_in_as(user)
    click_link "Ver el detalle"
    drawer = wait_for_drawer

    within(drawer) do
      expect(page).to have_css("h1", text: "Tareas pendientes") # not the home page
      expect(page).to have_no_css("h1", text: "Hola,")
      expect(page).to have_no_css("[role=tab]")
      titles = all("section[id^=pending-] > h2").map(&:text)
      expect(titles.first).to include("Compras sin facturar")
      expect(titles.last).to include("Préstamos vencidos")
      expect(find("#pending-uninvoiced")).to have_text("Ana Zelaya")
      expect(find("#pending-overdue_loans")).to have_text("Préstamo #{loan.id}")
    end
  end
end
