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
    find("#active-users li[data-presence-state=online]#presence_user_#{user.id}").hover
    find("#active-users li[data-presence-state=online]#presence_user_#{user.id} .presence-card")
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

  it "is a card you can move onto, scroll and click, which stays open while the panel updates" do
    [ ana, beto ].each { it.update!(admin: true) } # so Compras lets them in
    25.times { |i| PageVisit.record!(user: beto, path: "/trading/purchases?page=#{i}", title: "Compras #{i}", at: (30 - i).minutes.ago) }
    sign_in_as(ana)
    Capybara.using_session(:beto) { sign_in_as(beto) }

    card = card_of(beto)
    expect(card).to have_css("[data-presence-visits] li", count: Presence::CARD_ITEMS)
    list = card.find("[data-presence-visits]")
    list.hover # from the avatar onto the card: it stays open
    expect(card).to be_visible
    expect(list.evaluate_script("this.scrollHeight > this.clientHeight")).to be(true)
    list.execute_script("this.scrollTop = 120")

    Capybara.using_session(:beto) { visit trading_purchases_path }
    expect(card).to have_text("/trading/purchases", wait: 5)
    expect(card).to be_visible
    expect(list.evaluate_script("this.scrollTop")).to eq(120) # morphed, not swapped

    card.find("[data-presence-page] a").click
    expect(page).to have_current_path(trading_purchases_path)
  end

  it "is not told to anyone else" do
    Capybara.using_session(:beto) { sign_in_as(beto) }
    sign_in_as(create(:user, name: "Ciro Paz"))

    expect(card_of(beto)).to have_text("Beto Mejía")
    expect(page).to have_no_css("[data-presence-page]", visible: :all)
  end
end
