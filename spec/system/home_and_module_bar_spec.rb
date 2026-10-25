require "rails_helper"

# The home page uses its space with no gaps (figures and tiles fill their
# rows; activity is as tall as the left column), and a module's bar reads as
# a second tier, unlike the main menu's pills.
RSpec.describe "Home layout and module bar", type: :system do
  let(:user) { create(:user, :admin) }

  before do
    DemoData.new(user).load
    sign_in_as(user)
  end

  def bottom(selector) = page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().bottom")

  it "fills each row of figures and modules, and ends both columns together" do
    visit root_path
    expect(page).to have_css("#dashboard-activity")

    rows = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[aria-labelledby=dashboard-figures] dl > *, [aria-labelledby=dashboard-modules] .flex-wrap > *")]
        .reduce((rows, el) => { const r = el.getBoundingClientRect(), p = el.parentElement.getBoundingClientRect();
          const key = el.parentElement.tagName + Math.round(r.top); (rows[key] ||= { right: 0, parent: p.right }).right = Math.max(rows[key].right, r.right); return rows }, {})
    JS
    rows.each_value { |row| expect(row["right"]).to be_within(1).of(row["parent"]) }

    expect(bottom("[aria-labelledby=dashboard-activity]")).to be_within(1).of(bottom("[aria-labelledby=dashboard-modules]"))
  end

  it "keeps every block of the home page the same width on a phone, inside the page's gutters" do
    # A long name in recent activity, on one line, must not widen its column.
    create(:purchase, producer: create(:producer, person: create(:person, first_names: "María José Esperanza", last_names: "Rodríguez Maldonado")))
    page.driver.resize(390, 1600)
    visit root_path
    expect(page).to have_css("#dashboard-pending")

    edges = page.evaluate_script(<<~JS)
      ["[aria-labelledby=dashboard-figures]", "#coffee-market", "#dashboard-pending", "[aria-labelledby=dashboard-modules]", "[aria-labelledby=dashboard-activity]"]
        .map((selector) => { const r = document.querySelector(selector).getBoundingClientRect(); return [ Math.round(r.left), Math.round(r.right) ] })
    JS
    expect(edges.uniq).to eq([ [ 16, 374 ] ])
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(390)
  ensure
    page.driver.resize(1400, 1000)
  end

  it "marks the module's current page as an underlined tab, not as a pill like the main menu" do
    visit trading_purchases_path
    main = find("header nav a[href='#{trading_root_path}']")
    tab = find(".subnav a[aria-current=page]", text: "Compras")

    expect(main[:class]).to include("nav-pill-active")
    styles = ->(el) { el.evaluate_script("(() => { const s = getComputedStyle(this); return [s.backgroundColor, s.borderBottomWidth, s.borderRadius] })()") }
    main_bg, _, main_radius = styles.call(main)
    tab_bg, tab_border, tab_radius = styles.call(tab)
    expect(tab_bg).not_to eq(main_bg)
    expect(tab_border).to eq("3px")
    expect(tab_radius).to eq("0px")
    expect(main_radius).not_to eq("0px")
    expect(page).to have_css(".subnav .subnav-action a", text: "Nueva compra")
  end
end
