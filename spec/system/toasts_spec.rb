require "rails_helper"

# Notices and alerts show as toasts at the bottom right (toast_controller.js):
# over the page, closable, and a notice goes away by itself after 7 seconds.
RSpec.describe "Toasts", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  def create_zone(name)
    visit new_trading_zone_path
    fill_in "zone_name", with: name
    within("main form") { find("[type=submit]").click }
  end

  it "shows a notice at the bottom right, over the page, and closes it" do
    create_zone("Zona Norte")

    toast = find(".toast-region .toast.toast-shown", text: "Zona creada.")
    sleep 0.6 # done sliding in
    toast.hover # its time stops: a slow run does not lose it before the ×
    region = page.evaluate_script("(() => { const s = getComputedStyle(document.querySelector('.toast-region')); return [s.position, s.right, s.bottom] })()")
    expect(region).to eq([ "fixed", "16px", "16px" ])
    expect(page).to have_css("main h1") # the page starts right away, not under the notice

    toast.click_button("Cerrar mensaje")
    expect(page).to have_no_css(".toast")
  end

  it "takes a notice away by itself after 7 seconds, not while the pointer is on it" do
    create_zone("Zona Sur")
    toast = find(".toast.toast-shown", text: "Zona creada.")
    sleep 0.6 # done sliding in, so the pointer lands on it
    toast.hover
    sleep 7.5
    expect(page).to have_css(".toast", text: "Zona creada.")

    find("main h1").hover
    expect(page).to have_no_css(".toast", wait: 9)
  end

  it "stays above a modal or the help guide opened after it" do
    create_zone("Zona Este")
    find(".toast.toast-shown", text: "Zona creada.")
    on_top = lambda do
      page.evaluate_script(<<~JS)
        (() => {
          const toast = document.querySelector(".toast")
          const box = toast.getBoundingClientRect()
          return toast.contains(document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2))
        })()
      JS
    end

    click_link "Nueva zona"
    expect(page).to have_css("dialog[open] #zone_name")
    expect(on_top.call).to be(true)
    within("dialog[open]") { click_button "Cancelar" }

    find("header .help-button", match: :first).click
    expect(page).to have_css("dialog#help-guide[open]")
    expect(on_top.call).to be(true)

    # Usable there too: it closes from inside the guide.
    find(".toast").click_button("Cerrar mensaje")
    expect(page).to have_no_css(".toast-region")
  end

  it "keeps an alert until it is closed" do
    other = create(:user) # no permissions: the page sends back an alert
    visit root_path
    click_button "Cerrar sesión"
    sign_in_as(other)
    visit trading_zones_path

    expect(page).to have_css(".toast.toast-alert[role=alert]")
    sleep 8
    expect(page).to have_css(".toast.toast-alert")
  end
end
