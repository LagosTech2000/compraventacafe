require "rails_helper"

# The navigation's menu on phones (Fernando, 2026-10-13): a solid panel, the
# page never shows through it.
RSpec.describe "Mobile menu", type: :system do
  it "opens as a solid panel with the modules" do
    page.driver.resize(390, 844)
    sign_in_as(create(:user, :admin))
    find("header summary", text: "Menú").click

    menu = find("[data-mobile-menu]")
    expect(menu).to have_link("Compra de café")
    background, filter = page.evaluate_script(<<~JS)
      (() => { const s = getComputedStyle(document.querySelector("[data-mobile-menu]")); return [ s.backgroundColor, s.backdropFilter ] })()
    JS
    expect(background).to match(/\Argb\(\d+, \d+, \d+\)\z/) # no alpha: not see-through
    expect(filter).to eq("none")
  end
end
