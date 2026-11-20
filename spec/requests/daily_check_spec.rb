require "rails_helper"

# «¿Cuadra hoy?» (Fernando, 2026-11-18): a card of the Inicio for
# administrators, each line opening where it is fixed.
RSpec.describe "Daily check on the Inicio" do
  let(:admin) { create(:user, :admin) }
  include ActiveSupport::Testing::TimeHelpers

  # At noon: «1 hour ago» stays today, whatever the hour the suite runs.
  around { |example| travel_to(Time.zone.now.change(hour: 12)) { example.run } }

  def page = Nokogiri::HTML(response.body)
  def line(key) = page.at_css("[data-daily-check='#{key}']")

  it "says what keeps today from adding up, and that everything adds up once it is done" do
    box = create(:money_account, kind: "cash", opening_balance: 500)
    purchase = create(:purchase, purchased_at: 1.hour.ago)
    create(:shipment, departed_at: 30.minutes.ago, origin_gross_weight: 100, origin_sacks: 1)
    sign_in admin

    get root_path
    expect(page.at_css("[data-daily-check-status]").text).to eq("Falta")
    expect(line(:stock_counts).text).to include("1 café (estado y bodega) sin contar hoy")
    expect(line(:cash_counts).text).to include("1 caja sin arqueo hoy")
    expect(line(:uninvoiced).text).to include("1 de hoy sin facturar")
    expect(line(:shipments_without_lots).text).to include("1 de hoy sin lotes")
    expect(line(:negative_accounts).text).to include("ninguna en negativo")
    expect(line(:uninvoiced).at_css("a")["href"]).to eq(trading_purchases_path(status: "uninvoiced"))

    InvoiceIssuer.new(producer: purchase.producer, purchase_ids: [ purchase.id ], user: admin, payment_status: "pending").call
    CashCount.create!(money_account: box, counted_on: Time.zone.today, counted_amount: 490, created_by: admin)
    get root_path
    expect(line(:uninvoiced).text).to include("todas las de hoy están facturadas")
    expect(line(:cash_counts).text).to include("el arqueo de hoy difiere L 10.00")
  end

  it "is only for administrators" do
    sign_in create(:user).tap { create(:permission, user: it, module_key: "trading", can_read: true) }
    get root_path
    expect(page.at_css("#dashboard-daily-check")).to be_nil
  end
end
