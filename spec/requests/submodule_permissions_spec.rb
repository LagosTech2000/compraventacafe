require "rails_helper"

# Permissions per submodule (Fernando, 2026-11-12): view, create, edit and
# delete are given per tab of each module's bar. A module opens for whoever
# reads any of its tabs; each screen, menu tab, Resumen part, Inicio figure,
# report and money source goes with its own tab.
RSpec.describe "Permissions per submodule" do
  let(:today) { Time.zone.today }

  def page = Nokogiri::HTML(response.body)
  def subnav_tabs = page.css(".subnav a.nav-pill, .subnav a[class*='nav-pill']").map { it.text.strip }.uniq

  def user_with(*keys, **flags)
    create(:user).tap do |user|
      keys.each do |key|
        module_key, submodule_key = key.split(".")
        create(:permission, user:, module_key:, submodule_key:, can_read: true, **flags)
      end
    end.reload
  end

  it "opens only the screens of the tabs the user reads, and the module's bar shows only those" do
    sign_in user_with("trading.invoices")

    get trading_invoices_path
    expect(response).to have_http_status(:ok)
    expect(subnav_tabs).to include("Resumen", "Facturas")
    expect(subnav_tabs).not_to include("Compras", "Productores", "Carreros", "Zonas", "Cierre diario")

    get trading_purchases_path
    expect(response).to redirect_to(root_path)
    get trading_producers_path
    expect(response).to redirect_to(root_path)
  end

  it "gives each action of each tab apart" do
    user = user_with("trading.invoices")
    create(:permission, user:, module_key: "trading", submodule_key: "purchases", can_read: true, can_create: true)
    sign_in user

    get new_trading_purchase_path
    expect(response).to have_http_status(:ok)
    get new_trading_invoice_path
    expect(response).to redirect_to(root_path)
  end

  it "shows in a module's Resumen only the parts of the tabs the user reads" do
    sign_in user_with("trading.invoices")
    get trading_root_path
    expect(response).to have_http_status(:ok)
    steps = page.css("ol.grid > li").map { it.text.squish }
    expect(steps.size).to eq(1)
    expect(steps.first).to include(I18n.t("trading.home.index.steps.pay.title"))
    expect(response.body).not_to include(I18n.t("trading.home.index.today", date: I18n.l(today, format: :long)))
  end

  it "opens the module on the first tab the user reads when its Resumen has nothing for them" do
    sign_in user_with("trading.zones", "loans.supplies")
    get trading_root_path
    expect(response).to redirect_to(trading_zones_path)
    get loans_root_path
    expect(response).to redirect_to(loans_supplies_path)

    get trading_zones_path
    expect(subnav_tabs).not_to include("Resumen")
  end

  it "keeps expenses and investments apart" do
    sign_in user_with("finance.investments")
    create(:expense, description: "Gasto oculto")
    create(:expense, kind: "investment", description: "Inversión visible")

    get finance_investments_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Inversión visible")
    get finance_expenses_path
    expect(response).to redirect_to(root_path)
  end

  it "shows in the Inicio only the figures, pending work and debts of the tabs the user reads" do
    admin = create(:user, :admin)
    producer = create(:producer)
    create(:purchase, producer:)
    invoiced = create(:purchase, producer:)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ invoiced.id ], payment_status: "pending").call
    sign_in user_with("trading.invoices")

    get root_path
    figures = page.css("#dashboard-figures ~ dl .stat dt").map(&:text)
    expect(figures).not_to include("Compras de hoy")
    pending = page.at_css("#dashboard-pending").text.squish
    expect(pending).to include("1 factura sin cancelar")
    expect(pending).not_to include("sin facturar")
    expect(page.at_css("#dashboard-debts").text).to include(I18n.t("dashboard.show.debts.lines.invoices"))
  end

  it "shows each money source only to who reads its tab" do
    user = user_with("finance.movements", "trading.invoices")
    expect(MoneyMovements.sources_for(user)).to eq(%w[invoices])
    expect(MoneyMovements.sources_for(user_with("finance.staff"))).to eq(%w[staff_payments staff_advances])
  end

  it "opens a report only with the tab its data comes from" do
    sign_in user_with("reports.reports", "trading.invoices")
    get reports_report_path("invoices")
    expect(response).to have_http_status(:ok)
    get reports_report_path("purchases")
    expect(response).not_to have_http_status(:ok)
  end

  it "«Nueva salida» shows only the kinds the user can create" do
    user = user_with("sales.stock", can_create: true)
    sign_in user
    get new_sales_departure_path
    expect(response).to have_http_status(:ok)
    expect(page.css("[data-departure-kinds] a").map { it["href"] }).to eq([ new_sales_warehouse_transfer_path ])

    sign_in user_with("sales.buyers", can_create: true)
    get new_sales_departure_path
    expect(response).to redirect_to(root_path)
  end

  it "the cards beside «Nueva compra» and «Nuevo préstamo» go with purchases and loans" do
    producer = create(:producer)
    sign_in user_with("trading.purchases", "loans.loans")
    get trading_producer_card_path(producer)
    expect(response).to have_http_status(:ok)
    get loans_borrower_path(producer.person)
    expect(response).to have_http_status(:ok)

    sign_in user_with("trading.zones", "loans.supplies")
    get trading_producer_card_path(producer)
    expect(response).not_to have_http_status(:ok)
    get loans_borrower_path(producer.person)
    expect(response).not_to have_http_status(:ok)
  end
end
