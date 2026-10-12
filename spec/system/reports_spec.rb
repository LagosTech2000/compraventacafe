require "rails_helper"

# Every query on the reports screen reloads only the "report" Turbo Frame:
# the page itself must never reload. A marker on <body> survives a frame
# navigation and is lost when the page loads again, by the browser or by a
# Turbo Drive visit (which swaps the whole body).
RSpec.describe "Reports screen", type: :system do
  let(:user) { create(:user, :admin) }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"

  before do
    zone = create(:zone, name: "Zona Sur")
    create(:purchase, producer: create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")),
                      zone:, purchased_at: Time.current.beginning_of_day + 8.hours)
    create(:purchase, producer: create(:producer, person: create(:person, first_names: "Bruno", last_names: "Aguilar")),
                      purchased_at: Time.current.beginning_of_day + 9.hours)
    sign_in_as(user)
    visit reports_report_path("purchases")
    expect(page).to have_css("h1", text: "Compras")
    mark_page
  end

  def producers_in_table = all("#report-rows tr td:nth-child(2)").map(&:text)

  it "sorts a column without reloading the page and keeps the URL" do
    within("#report-rows") { expect(page).to have_text("Ana Zelaya") }
    # Headers show in capitals (CSS): match them in any case.
    find("th", text: /\Aproductor\z/i).click_link
    expect(page).to have_css("th[aria-sort=descending]", text: /productor/i)
    sorted = producers_in_table
    find("th", text: /productor/i).click_link
    expect(page).to have_css("th[aria-sort=ascending]", text: /productor/i)
    expect(producers_in_table).to eq(sorted.reverse)

    expect(page).to have_current_path(/sort=producer/)
    expect(page_reloaded?).to be(false)
  end

  it "filters and groups without reloading the page" do
    select "Zona", from: "group"
    click_button "Filtrar"

    expect(page).to have_css("#report-rows-title", text: "Agrupado por Zona")
    expect(page).to have_current_path(/group=zone/)
    expect(page_reloaded?).to be(false)
  end

  it "switches to another report without reloading the page" do
    select "Facturas", from: "report_type"

    expect(page).to have_css("h1", text: "Facturas")
    expect(page).to have_current_path(reports_report_path("invoices"))
    expect(page_reloaded?).to be(false)
  end

  it "goes back to the previous query with the back button" do
    # The frame visit ends with turbo:load, once the history entry is in place.
    page.execute_script("document.addEventListener('turbo:load', () => { document.body.dataset.visited = 'yes' }, { once: true })")
    select "Zona", from: "group"
    click_button "Filtrar"
    expect(page).to have_css("#report-rows-title", text: "Agrupado por Zona")
    expect(page).to have_css("body[data-visited=yes]")

    page.go_back
    expect(page).to have_no_css("#report-rows-title", text: "Agrupado por")
    expect(page).to have_current_path(reports_report_path("purchases"))
  end

  it "loads the next rows as the list scrolls, without reloading the page" do
    producer = create(:producer)
    51.times { |hour| create(:purchase, producer:, purchased_at: Time.current.beginning_of_day + (hour % 10).hours + hour.minutes) }
    visit reports_report_path("purchases")
    mark_page

    expect(page).to have_css("#report-rows tr", count: 50)
    page.execute_script("document.getElementById('report-more').scrollIntoView({ block: 'center' })")
    expect(page).to have_css("#report-rows tr", count: 53)
    expect(page).to have_text("Son todos: 53 registros.")
    expect(page_reloaded?).to be(false)
  end

  it "opens one of my saved filters from its window into the report, without reloading the page" do
    SavedReport.create!(user:, report_key: "purchases", name: "Por zona", params: { "group" => "zone" })
    visit reports_report_path("invoices")
    mark_page

    click_link "Administrar"
    within("dialog[open]") { click_link "Abrir" }

    expect(page).to have_css("#report-rows-title", text: "Agrupado por Zona")
    expect(page).to have_no_css("dialog[open]")
    expect(page_reloaded?).to be(false)
  end

  it "keeps the scroll position when sorting a column further down" do
    producer = create(:producer)
    30.times { |minute| create(:purchase, producer:, purchased_at: Time.current.beginning_of_day + 6.hours + minute.minutes) }
    visit reports_report_path("purchases")
    expect(page).to have_css("#report-rows tr", count: 32)
    # Where the table sits on the screen must stay put. ("| 0": a -0 comes
    # back from the browser as nil.)
    table_top = -> { page.evaluate_script("Math.round(document.querySelector('#report-rows-title').getBoundingClientRect().top) | 0") }
    page.execute_script("document.querySelector('#report-rows-title').scrollIntoView()")
    expect(page.evaluate_script("window.scrollY")).to be > 300
    top_before = table_top.call

    # Clicked from JavaScript: Capybara's click would scroll to the link first.
    find("th", text: /\Atotal\z/i).find("a").execute_script("this.click()")
    expect(page).to have_css("th[aria-sort]", text: /total/i)
    expect(page).to have_current_path(/sort=total/)
    # Without keeping it, the table ends a whole screen away (or at the top of the page).
    expect(table_top.call).to be_within(40).of(top_before)
  end

  it "keeps the charts when sorting and reloads them when filtering" do
    expect(page).to have_css("#report-charts canvas")
    page.execute_script("document.querySelector('#report-charts').dataset.kept = 'yes'")

    find("th", text: /\Aproductor\z/i).click_link
    expect(page).to have_css("th[aria-sort]", text: /productor/i)
    expect(page).to have_css("#report-charts[data-kept=yes]")

    select "Zona", from: "group"
    click_button "Filtrar"
    expect(page).to have_css("#report-rows-title", text: "Agrupado por Zona")
    expect(page).to have_no_css("#report-charts[data-kept=yes]")
    expect(page).to have_css("#report-charts canvas")
  end

  it "names the browser tab after the report it switched to" do
    select "Facturas", from: "report_type"
    expect(page).to have_css("h1", text: "Facturas")
    expect(page).to have_title(/\AFacturas · Reportería/)
  end
end
