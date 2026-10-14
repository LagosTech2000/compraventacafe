require "rails_helper"

# The left navigation (layouts/_sidebar, sidebar_controller.js): collapses to
# its icons, which grow and show their name in a tooltip on hover without
# widening the bar, and stays collapsed on the next pages.
RSpec.describe "Left navigation", type: :system do
  let(:user) { create(:user, :admin, nav_position: "left") }

  def width_of(selector) = page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
  def scale_of(selector) = page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).scale")

  before { sign_in_as(user) }

  it "collapses to its icons, names them on hover and remembers it" do
    expect(page).to have_css("aside .sidebar-label", text: "Compra de café", visible: true)
    expect(width_of("aside")).to eq(256)

    click_button "Esconder el menú (solo íconos)"
    expect(page).to have_css("body.sidebar-collapsed")
    expect(page).to have_no_css("aside .sidebar-label", text: "Compra de café", visible: true)
    sleep 0.3 # the width animates
    expect(width_of("aside")).to eq(76)

    link = find("aside a.sidebar-link[href='#{trading_root_path}']")
    link.hover
    expect(page).to have_css("aside .sidebar-label", text: "Compra de café", visible: true)
    expect(width_of("aside")).to eq(76) # the tooltip goes over the page
    sleep 0.2
    expect(scale_of("aside a.sidebar-link[href='#{trading_root_path}'] .sidebar-icon")).to eq("1.25")

    visit trading_root_path
    expect(page).to have_css("body.sidebar-collapsed")
    click_button "Mostrar el menú completo"
    expect(page).to have_css("aside .sidebar-label", text: "Compra de café", visible: true)

    visit root_path
    expect(page).to have_no_css("body.sidebar-collapsed")
  end
end
