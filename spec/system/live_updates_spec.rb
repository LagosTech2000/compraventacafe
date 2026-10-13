require "rails_helper"

# Pages that update themselves while open (LiveUpdates): a change made by
# someone else shows without reloading, new rows glow in and changed figures
# pulse (live_refresh_controller.js), and an open window delays it.
RSpec.describe "Live updates", type: :system do
  let(:user) { create(:user, :admin) }
  let(:clerk) { create(:user, :admin) }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }

  # A morph keeps the window but syncs <body>'s attributes: mark the window.
  def mark_page = page.execute_script("window.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("window.pageMarker") != "still here"
  def figure(label) = find(".stat dt", text: /\A#{label}\z/i).find(:xpath, "..").find("dd")

  # Broadcasts go through a debounced job: run it right away here.
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  before { sign_in_as(user) }

  it "adds someone else's purchase to the list and its totals, with a glow, without reloading" do
    create(:purchase, producer:, created_by: clerk)
    visit trading_purchases_path
    expect(page).to have_css(".live-badge", text: "En vivo")
    expect(figure("Compras")).to have_text("1")
    mark_page

    purchase = create(:purchase, producer:, created_by: clerk, gross_weight: 330)
    expect(page).to have_css("#purchases-list tr##{ActionView::RecordIdentifier.dom_id(purchase)}.live-new")
    expect(figure("Compras")).to have_text("2")
    expect(page).to have_css(".stat dd.live-changed", wait: 1)
    expect(page_reloaded?).to be(false)
    expect(page).to have_no_button("Filtrar") # hidden by the live filters, kept hidden
    expect(page).to have_css(".live-badge", text: "En vivo")
  end

  it "updates the daily close and the module summary" do
    visit trading_daily_close_path
    mark_page
    create(:purchase, producer:, created_by: clerk)
    expect(page).to have_css("tr[id^=purchase_]", text: "Ana Zelaya")
    expect(page_reloaded?).to be(false)

    visit trading_root_path
    expect(page).to have_css(".live-badge", text: "En vivo")
    before_text = find("[data-live-value='step-invoice']").text
    create(:purchase, producer:, created_by: clerk)
    expect(page).to have_no_css("[data-live-value='step-invoice']", exact_text: before_text)
  end

  it "waits while a window is open, and updates once it closes" do
    first = create(:purchase, producer:, created_by: clerk)
    visit trading_purchases_path
    expect(page).to have_css(".live-badge", text: "En vivo")
    within("tr##{ActionView::RecordIdentifier.dom_id(first)}") { click_link "Detalle" }
    expect(page).to have_css("dialog[open] h1", text: "Compra #{first.id}")

    second = create(:purchase, producer:, created_by: clerk)
    sleep 1.5
    expect(page).to have_css("dialog[open] h1", text: "Compra #{first.id}")
    expect(page).to have_no_css("tr##{ActionView::RecordIdentifier.dom_id(second)}")

    find("dialog[open]").send_keys(:escape)
    expect(page).to have_css("tr##{ActionView::RecordIdentifier.dom_id(second)}")
  end

  it "updates the loans summary when a loan is registered" do
    visit loans_root_path
    expect(page).to have_css(".live-badge", text: "En vivo")
    expect(figure("Préstamos por cobrar")).to have_text("0")

    create(:loan, created_by: clerk)
    expect(figure("Préstamos por cobrar")).to have_text("1")
  end

  it "keeps the toast on screen through an update" do
    visit trading_purchases_path(notice_test: 1)
    page.execute_script(<<~JS)
      const region = document.createElement("div")
      region.className = "toast-region"
      region.innerHTML = "<div class='toast'>Aviso de prueba</div>"
      document.body.append(region)
    JS
    expect(page).to have_css(".live-badge", text: "En vivo")
    create(:purchase, producer:, created_by: clerk)
    expect(page).to have_css("tr[id^=purchase_]", text: "Ana Zelaya")
    expect(page).to have_css(".toast", text: "Aviso de prueba", visible: :all)
  end
end
