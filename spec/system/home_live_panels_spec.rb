require "rails_helper"

# The home page's coffee exchange card (CoffeeMarket, loaded apart) and the
# users online now (Presence), which updates by itself.
RSpec.describe "Home page panels", type: :system do
  let(:ana) { create(:user, name: "Ana Zelaya") }
  let(:beto) { create(:user, name: "Beto Mejía") }

  it "loads the coffee exchange price apart" do
    coffee_market_responds_with
    sign_in_as(ana)

    within("turbo-frame#coffee-market") do
      expect(page).to have_text("Café en la bolsa")
      expect(page).to have_text("293.20")
      expect(page).to have_text("▲ 6.25 (2.18%)")
    end
  end

  it "sits on the greeting's row, at the other end" do
    sign_in_as(ana)
    expect(page).to have_css("#active-users li[aria-label='Ana Zelaya']")
    greeting, avatar = page.evaluate_script(<<~JS)
      [ "main h1", "#active-users li" ].map((s) => { const r = document.querySelector(s).getBoundingClientRect(); return { top: r.top, bottom: r.bottom, left: r.left, right: r.right } })
    JS

    expect(avatar["top"]).to be < greeting["bottom"]
    expect(avatar["left"]).to be > greeting["right"]
    expect(avatar["right"] - avatar["left"]).to be <= 32 # small circles
  end

  it "shows who comes and goes without reloading, never the hidden user" do
    hidden = create(:user, name: "Dueño Oculto")
    stub_const("Presence::HIDDEN_USER_IDS", [ hidden.id ])
    sign_in_as(ana)
    expect(page).to have_css("#active-users li[aria-label='Ana Zelaya']", text: "AZ")
    expect(page).to have_no_css(".presence-card", text: "Ana Zelaya") # only on hover
    find("#active-users li[aria-label='Ana Zelaya']").hover
    expect(page).to have_css(".presence-card", text: "Ana Zelaya")
    page.execute_script("window.pageMarker = 'still here'")

    Capybara.using_session(:beto) { sign_in_as(beto) }
    expect(page).to have_css("#active-users li[aria-label='Beto Mejía']")
    Capybara.using_session(:hidden) { sign_in_as(hidden) }

    Capybara.using_session(:beto) { find("header").click_button("Cerrar sesión") }
    expect(page).to have_no_css("#active-users li[aria-label='Beto Mejía']")
    expect(page).to have_no_css("#active-users li[aria-label='Dueño Oculto']", visible: :all)
    expect(page.evaluate_script("window.pageMarker")).to eq("still here")

    Capybara.using_session(:hidden) do
      expect(page).to have_css("#active-users li[aria-label='Ana Zelaya']")
      expect(page).to have_no_css("#active-users li[aria-label='Dueño Oculto']", visible: :all)
    end
  end

  it "opens the pending work from its figure, and back from a payment on top" do
    admin = create(:user, :admin, name: "Ana Zelaya")
    purchase = create(:purchase)
    InvoiceIssuer.new(producer: purchase.producer, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call
    sign_in_as(admin)

    find(".stat", text: "PENDIENTES").click
    within("dialog[open]") do
      expect(page).to have_css("h1", text: "Tareas pendientes")
      expect(page).to have_css("#pending-unpaid_invoices", text: "Factura 0001")
      click_link "Registrar abono"
    end
    expect(page).to have_css("dialog[open]", count: 2)
    within(all("dialog[open]").last) { click_button "Atrás" }
    expect(page).to have_css("dialog[open]", count: 1)
    expect(page).to have_css("dialog[open] h1", text: "Tareas pendientes")
  end
end
