require "rails_helper"

# The user with id 1 (Presence::WATCHER_IDS) sees, hovering over who is
# connected, their last activity and the page they are on, as it changes.
RSpec.describe "Pages of who is connected", type: :system do
  let(:ana) { create(:user, name: "Ana Zelaya") }
  let(:beto) { create(:user, name: "Beto Mejía") }

  before do
    stub_const("Presence::HIDDEN_USER_IDS", [ ana.id ])
    stub_const("Presence::WATCHER_IDS", [ ana.id ])
  end

  def card_of(user)
    find("#active-users li#online_user_#{user.id}").hover
    find("#active-users li#online_user_#{user.id} .online-tooltip")
  end

  it "follows the page, also one opened in a modal, without reloading" do
    sign_in_as(ana)
    page.execute_script("window.pageMarker = 'still here'")

    Capybara.using_session(:beto) { sign_in_as(beto) }
    expect(card_of(beto)).to have_text(/Está en:\s+Inicio/)
    expect(card_of(beto)).to have_text("Última actividad:")

    Capybara.using_session(:beto) do
      find("header a[title^='Mi configuración']").click
      expect(page).to have_css("dialog[open] h1", text: "Mi configuración")
    end
    expect(card_of(beto)).to have_text("Mi configuración")
    expect(card_of(beto)).to have_text("/user_setting/edit")

    Capybara.using_session(:beto) do
      within("dialog[open]") { find("button[aria-label='Cerrar']").click }
      expect(page).to have_no_css("dialog[open]")
    end
    expect(card_of(beto)).to have_text(/Está en:\s+Inicio/)
    expect(page.evaluate_script("window.pageMarker")).to eq("still here")
  end

  it "is not told to anyone else" do
    Capybara.using_session(:beto) { sign_in_as(beto) }
    sign_in_as(create(:user, name: "Ciro Paz"))

    expect(card_of(beto)).to have_text("Beto Mejía")
    expect(page).to have_no_css("[data-presence-page]", visible: :all)
  end
end
