require "rails_helper"

# A modal closes on a click on its backdrop only when the click starts there
# too (modal_controller.js): selecting text in a field and letting go
# outside the window keeps the form and what was typed.
RSpec.describe "Modal backdrop", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  def mouse = page.driver.browser.mouse
  def center_of(selector) = page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2] })()")

  it "keeps the form when a text selection ends outside the window, and closes on a real backdrop click" do
    visit administration_people_path
    click_link "Nueva persona"
    within("dialog[open]") { fill_in "person_first_names", with: "María José" }

    x, y = center_of("dialog[open] #person_first_names")
    mouse.move(x: x + 40, y:).down.move(x: 5, y: 5).up
    expect(page).to have_css("dialog[open]")
    expect(page).to have_field("person_first_names", with: "María José")

    mouse.move(x: 5, y: 5).down.up
    expect(page).to have_no_css("dialog[open]")
  end

  it "does the same with the help guide" do
    visit administration_people_path
    find("header .help-button", match: :first).click
    expect(page).to have_css("dialog#help-guide[open]")

    x, y = center_of("dialog#help-guide[open] h2")
    mouse.move(x:, y:).down.move(x: 5, y: 500).up
    expect(page).to have_css("dialog#help-guide[open]")

    mouse.move(x: 5, y: 500).down.up
    expect(page).to have_no_css("dialog#help-guide[open]")
  end
end
