require "rails_helper"

# Each user's display settings (Fernando, 2026-10-13): pages over the page in
# a modal or a drawer, with "Atrás" (modal_controller.js), and the main
# navigation at the top or on the left.
RSpec.describe "User settings", type: :system do
  let(:user) { create(:user, :admin, name: "Ana Zelaya") }

  def open_invoice
    purchase = create(:purchase)
    InvoiceIssuer.new(producer: purchase.producer, user:, purchase_ids: [ purchase.id ], payment_status: "pending").call
    visit trading_invoices_path
    click_link "Detalle"
  end

  it "saves the choices from the user's name and the page follows them" do
    sign_in_as(user)
    click_link "Ana Zelaya"
    within("dialog[open]") do
      expect(page).to have_css("h1", text: "Mi configuración")
      choose "En un panel lateral (drawer)"
      choose "A la izquierda"
      click_button "Guardar configuración"
    end

    expect(page).to have_css(".toast", text: "Tu configuración quedó guardada.")
    expect(page).to have_css("aside nav", text: "Compra de café")
    expect(page).to have_no_css("header nav")
    expect(page).to have_css("dialog.modal.drawer", count: ModalSupport::MODAL_FRAMES.size, visible: :all)
    expect(user.reload).to have_attributes(window_style: "drawer", nav_position: "left")
  end

  it "sizes the drawer to its page, up to 90% of the width" do
    user.update!(window_style: "drawer")
    sign_in_as(user)
    drawer_width = -> { page.evaluate_script("document.querySelector('dialog.drawer[open]').getBoundingClientRect().width") }
    window_width = page.evaluate_script("window.innerWidth")

    visit trading_zones_path
    click_link "Nueva zona"
    wait_for_drawer
    expect(page).to have_field("zone_name")
    expect(drawer_width.call).to be < window_width * 0.6 # a short form, not a mostly empty panel
    expect(drawer_width.call).to be >= 34 * 16 - 1

    open_invoice # a page with tables takes the whole 90%
    wait_for_drawer
    expect(page).to have_css("dialog.drawer[open] table")
    expect(drawer_width.call).to be_within(2).of(window_width * 0.9)
  end

  it "navigates inside the drawer and goes back" do
    user.update!(window_style: "drawer")
    sign_in_as(user)
    open_invoice

    drawer = wait_for_drawer
    expect(drawer).to have_no_button("Atrás")
    expect(drawer).to have_link("Registrar abono")
    drawer.click_link "Registrar abono"

    expect(page).to have_css("dialog.drawer[open]", count: 1)
    expect(drawer).to have_css("h1", text: "Registrar abono")
    drawer.click_button "Atrás"

    expect(drawer).to have_link("Registrar abono")
    expect(drawer).to have_no_button("Atrás")
    expect(page).to have_css("dialog.drawer[open]", count: 1)
  end

  it "goes back from a modal opened on top of another by closing it" do
    sign_in_as(user)
    visit administration_people_path
    click_link "Nueva persona"
    within("dialog[open]") do
      expect(page).to have_no_button("Atrás")
      fill_in "person_first_names", with: "Rosa"
      click_link "Nueva zona"
    end

    expect(page).to have_css("dialog[open]", count: 2)
    within(all("dialog[open]").last) { click_button "Atrás" }

    expect(page).to have_css("dialog[open]", count: 1)
    expect(page).to have_field("person_first_names", with: "Rosa")
  end
end
