require "rails_helper"

# «Cuadrar inventario» and «Cuadrar cuentas» (Fernando, 2026-11-23): every
# state of every warehouse, and every account, counted on one page; the rows
# written are saved together or not at all.
RSpec.describe "Squaring the stock and the accounts" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "counts several states at once and leaves the stock as counted" do
    create(:purchase, gross_weight: 1_000, purchased_at: 1.day.ago)
    create(:purchase, coffee_state: "dry_parchment", humidity_percent: 12, gross_weight: 500, purchased_at: 1.day.ago)
    main = Warehouse.main!

    get new_sales_stock_square_path
    expect(page.css("[data-stock-square='#{main.id}'] tbody tr").size).to eq(Purchase::COFFEE_STATES.size)

    post sales_stock_square_path, params: { entries: {
      "#{main.id}_wet_parchment" => { counted_gross: "990", reason: "drying" },
      "#{main.id}_dry_parchment" => { counted_gross: "500" },
      "#{main.id}_cherry" => { counted_gross: "" }
    } }
    expect(response).to redirect_to(sales_stock_counts_path)
    expect(StockCount.count).to eq(2)
    expect(CoffeeStock.new(warehouse: main).row("wet_parchment").gross_stock).to eq(990)
  end

  it "saves none when one row fails, and says why under it" do
    create(:purchase, gross_weight: 1_000, purchased_at: 1.day.ago)
    main = Warehouse.main!
    post sales_stock_square_path, params: { entries: {
      "#{main.id}_wet_parchment" => { counted_gross: "900" },
      "#{main.id}_dry_parchment" => { counted_gross: "0" }
    } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(StockCount.count).to eq(0)
    expect(page.at_css("#square_#{main.id}_wet_parchment [role=alert]").text).to include("Motivo")

    post sales_stock_square_path, params: { entries: {} }
    expect(response.body).to include("Escribe al menos un conteo")
  end

  it "counts every account at once and leaves each with what was counted" do
    box = create(:money_account, name: "Caja", opening_balance: 2_000)
    bank = create(:money_account, name: "Banco", kind: "bank", opening_balance: 5_000)

    get new_finance_account_square_path
    expect(page.css("[data-account-square] tbody tr").size).to eq(2)

    post finance_account_square_path, params: { entries: { box.id.to_s => { counted_amount: "1,950", observations: "Faltan 50" },
                                                           bank.id.to_s => { counted_amount: "" } } }
    expect(response).to redirect_to(finance_money_accounts_path)
    expect(CashCount.sole).to have_attributes(money_account: box, counted_amount: 1_950, adjustment: -50)
    expect(AccountBalance.new.for(box)).to eq(1_950)
    expect(AccountBalance.new.for(bank)).to eq(5_000)
  end
end
