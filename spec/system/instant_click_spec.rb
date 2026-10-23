require "rails_helper"

# A page starts loading when the mouse button goes down on its link
# (instant_click.js), never just by resting the pointer on it.
RSpec.describe "Instant click", type: :system do
  let(:user) { create(:user, :admin) }

  def fetched?(path)
    page.evaluate_script("performance.getEntriesByType('resource').some((entry) => new URL(entry.name).pathname === '#{path}')")
  end

  def on_link(path, event)
    page.execute_script(<<~JS)
      document.querySelector("main a[href='#{path}'], nav a[href='#{path}']")
        .dispatchEvent(new MouseEvent("#{event}", { bubbles: true, button: 0 }))
    JS
  end

  before { sign_in_as(user) }

  it "asks for the page on the press, not on hover, and the click shows it" do
    visit trading_root_path

    on_link(trading_purchases_path, "mouseenter")
    sleep 0.3
    expect(fetched?(trading_purchases_path)).to be(false)

    on_link(trading_purchases_path, "mousedown")
    expect(Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until fetched?(trading_purchases_path); true }).to be(true)
    expect(page).to have_current_path(trading_root_path)

    find("a[href='#{trading_purchases_path}']", match: :first).click
    expect(page).to have_current_path(trading_purchases_path)
    expect(page).to have_css("h1", text: "Compras")
  end
end
