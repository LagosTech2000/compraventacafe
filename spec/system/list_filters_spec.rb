require "rails_helper"

# Purchases and invoices lists: filters apply as they change, without a
# button and without reloading the page (live_filter_controller.js); quick
# periods; the active filters as chips that remove themselves.
RSpec.describe "Live list filters", type: :system do
  let(:user) { create(:user, :admin) }
  let(:south) { create(:zone, name: "Zona Sur") }
  let(:ana) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }
  let(:bruno) { create(:producer, person: create(:person, first_names: "Bruno", last_names: "Aguilar")) }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"
  def rows = all("#purchases-list tr[id^=purchase_]")

  before do
    create(:purchase, producer: ana, zone: south, purchased_at: Time.current.change(hour: 8))
    create(:purchase, producer: bruno, purchased_at: Time.current.change(hour: 9))
    create(:purchase, producer: bruno, purchased_at: 1.day.ago.change(hour: 9))
    sign_in_as(user)
  end

  it "filters purchases as the user goes, keeping the page and what is being typed" do
    visit trading_purchases_path
    mark_page
    expect(page).to have_no_button("Filtrar")
    expect(page).to have_css("button.chip-active", text: "Hoy")
    expect(page).to have_text("2 compras")

    fill_in "q", with: "zel"
    expect(page).to have_text("1 compra")
    expect(rows.size).to eq(1)
    expect(page).to have_css(".chip-filter", text: "Productor: zel")
    expect(page.evaluate_script("document.activeElement.name")).to eq("q") # still typing there
    expect(page).to have_field("q", with: "zel")

    click_button "Ayer"
    expect(page).to have_css("button.chip-active", text: "Ayer")
    expect(page).to have_text("Ninguna compra")
    fill_in "q", with: ""
    expect(page).to have_text("1 compra")
    expect(page).to have_current_path(/from=#{1.day.ago.to_date.iso8601}/)

    click_button "Todo"
    expect(page).to have_text("3 compras")
    expect(page).to have_css(".chip-filter", text: "Todas las fechas")
    expect(page_reloaded?).to be(false)
  end

  it "shows each active filter as a chip that removes itself, and clears them all" do
    visit trading_purchases_path
    mark_page

    select "Zona Sur", from: "zone_id"
    expect(page).to have_css(".chip-filter", text: "Zona: Zona Sur")
    expect(page).to have_text("1 compra")

    click_button "Quitar el filtro Zona: Zona Sur"
    expect(page).to have_no_css(".chip-filter")
    expect(page).to have_select("zone_id", selected: "Todas las zonas")
    expect(page).to have_text("2 compras")

    select "Facturadas", from: "invoiced"
    click_button "Todo"
    expect(page).to have_css(".chip-filter", count: 2)
    click_button "Limpiar todo"
    expect(page).to have_no_css(".chip-filter")
    expect(page).to have_css("button.chip-active", text: "Hoy")
    expect(page_reloaded?).to be(false)
  end

  it "filters invoices by payment status right when it changes" do
    paid = InvoiceIssuer.new(producer: ana, user:, purchase_ids: [ ana.purchases.first.id ], payment_status: "paid", payment_method: "cash").call.invoice
    InvoiceIssuer.new(producer: bruno, user:, purchase_ids: bruno.purchases.pluck(:id), payment_status: "pending").call
    visit trading_invoices_path
    mark_page
    expect(page).to have_text("2 facturas")

    select "Cancelada", from: "payment_status"
    expect(page).to have_text("1 factura")
    expect(all("#invoices-list tr[id^=invoice_]").map { |row| row[:id] }).to eq([ "invoice_#{paid.id}" ])
    expect(page_reloaded?).to be(false)
  end

  it "loads the next purchases while scrolling, keeping the filters" do
    producer = create(:producer)
    51.times { |minute| create(:purchase, producer:, purchased_at: 2.days.ago.change(hour: 7) + minute.minutes) }
    visit trading_purchases_path
    click_button "Todo"
    expect(page).to have_text("54 compras")
    expect(page).to have_current_path(/from=&/) # the query is in the history: the visit is done
    expect(rows.size).to eq(50)
    mark_page

    page.execute_script("document.querySelector('#purchases-list [data-controller=infinite-list]').scrollIntoView()")
    expect(page).to have_css("#purchases-list tr[id^=purchase_]", count: 54)
    expect(page).to have_css("#purchases-list li.data-card", count: 54, visible: :all)
    expect(page).to have_no_button("Cargar más")
    expect(page).to have_no_link("Siguiente")
    expect(page).to have_css(".chip-filter", text: "Todas las fechas")
    expect(page_reloaded?).to be(false)
  end
end
