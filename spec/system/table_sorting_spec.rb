require "rails_helper"

# Every column sorts (Fernando, 2026-10-13). Lists that load page by page
# sort on the server, inside their frame, without reloading the page, and
# keep the order when a filter changes; tables that show all their rows sort
# in the browser (table_sort_controller.js): up, down, back to as they came.
RSpec.describe "Sorting tables", type: :system do
  let(:user) { create(:user, :admin) }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"
  def zone_names = all("#zones-list tbody tr td:first-child").map(&:text)

  before { sign_in_as(user) }

  it "sorts a list on the server without reloading, and keeps the order when filtering" do # (this list's filter loads the page)
    %w[Bravo Álamo Copán Zacapa].each { create(:zone, name: it) }
    visit trading_zones_path
    mark_page

    find("#zones-list th a", text: "NOMBRE").click
    expect(page).to have_css("#zones-list th[aria-sort=ascending]")
    expect(zone_names).to eq(%w[Álamo Bravo Copán Zacapa])
    expect(page).to have_current_path(/sort=name/)
    expect(page).to have_current_path(/dir=asc/)

    find("#zones-list th a", text: "NOMBRE").click
    expect(page).to have_css("#zones-list th[aria-sort=descending]")
    expect(zone_names).to eq(%w[Zacapa Copán Bravo Álamo])
    expect(page_reloaded?).to be(false)

    fill_in "q", with: "a"
    click_button "Filtrar"
    expect(page).to have_current_path(/q=a/)
    expect(page).to have_css("#zones-list th[aria-sort=descending]")
    expect(zone_names).to eq(%w[Zacapa Bravo Álamo]) # "Copán" has no plain "a"
  end

  it "keeps the order of a live list when its filters change" do
    producer = create(:producer)
    [ 300, 100, 200 ].each { |price| create(:purchase, producer:, price_per_pound: price / 10.0) }
    visit trading_purchases_path
    mark_page

    find("#purchases-list th a", text: "TOTAL").click
    expect(page).to have_css("#purchases-list th[aria-sort=ascending]", text: "TOTAL")
    totals = -> { all("#purchases-list tbody tr td:nth-child(9)").map { it.text.delete("L ,").to_f } }
    expect(totals.call).to eq(totals.call.sort)

    select "Pergamino húmedo", from: "coffee_state"
    expect(page).to have_css(".chip-filter", text: "Pergamino húmedo")
    expect(page).to have_css("#purchases-list th[aria-sort=ascending]", text: "TOTAL")
    expect(page_reloaded?).to be(false)
  end

  it "sorts a table that shows all its rows in the browser" do
    seed, lime, urea = [ "Semilla", "Cal", "Urea" ].map { create(:supply, name: it) }
    loan = create(:loan, cash_amount: 0, supply_items_attributes: [
      { supply_id: seed.id, quantity: 1, unit_price: 500 },
      { supply_id: lime.id, quantity: 3, unit_price: 1_000 },
      { supply_id: urea.id, quantity: 2, unit_price: 100 }
    ])
    visit loans_loan_path(loan)
    table = find("table[data-controller=table-sort]", text: "Semilla")
    names = -> { table.all("tbody tr td:first-child").map(&:text) }
    expect(names.call).to eq(%w[Semilla Cal Urea])

    table.click_button "Subtotal"
    expect(names.call).to eq(%w[Urea Semilla Cal])
    table.click_button "Subtotal"
    expect(names.call).to eq(%w[Cal Semilla Urea])
    table.click_button "Subtotal"
    expect(names.call).to eq(%w[Semilla Cal Urea])

    table.click_button "Insumo"
    expect(names.call).to eq(%w[Cal Semilla Urea])
  end
end
