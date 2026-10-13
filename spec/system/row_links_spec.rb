require "rails_helper"

# A click anywhere on a list row opens it like its "Detalle"/"Abrir" button
# (row_link_controller.js); the button stays, and the row's own controls
# keep doing their own thing.
RSpec.describe "Rows that open with a click", type: :system do
  let(:user) { create(:user, :admin) }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }

  before { sign_in_as(user) }

  it "opens a purchase in the modal from any cell of its row, and from its card on a phone" do
    purchase = create(:purchase, producer:)
    visit trading_purchases_path

    find("#purchases-list tr##{ActionView::RecordIdentifier.dom_id(purchase)} td", text: "Ana Zelaya").click
    expect(page).to have_css("dialog[open] h1", text: "Compra #{purchase.id}")
    find("dialog[open]").send_keys(:escape)
    expect(page).to have_no_css("dialog[open]")

    within("#purchases-list tr##{ActionView::RecordIdentifier.dom_id(purchase)}") { click_link "Detalle" }
    expect(page).to have_css("dialog[open] h1", text: "Compra #{purchase.id}")

    page.driver.resize(390, 800)
    visit trading_purchases_path
    find("##{ActionView::RecordIdentifier.dom_id(purchase, :card)} dl").click
    expect(page).to have_css("dialog[open] h1", text: "Compra #{purchase.id}")
  ensure
    page.driver.resize(1440, 1000)
  end

  it "leaves the row's own buttons alone" do
    purchase = create(:purchase, producer:)
    visit trading_purchases_path
    accept_confirm { within("tr##{ActionView::RecordIdentifier.dom_id(purchase)}") { click_button "Anular" } }
    expect(page).to have_text("anulada")
    expect(page).to have_no_css("dialog[open] h1", text: "Compra #{purchase.id}")
  end

  it "opens a payroll page from its row" do
    payroll = create(:payroll, name: "Limpia de cafetal")
    visit farms_payrolls_path
    find("tr", text: "Limpia de cafetal").find("td", text: payroll.farm.name).click
    expect(page).to have_current_path(farms_payroll_path(payroll))
  end
end
