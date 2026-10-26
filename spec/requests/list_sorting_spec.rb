require "rails_helper"

# Every column of every list sorts (Fernando, 2026-10-13): each list that
# loads page by page answers every column it declares (ListFilter#sorts),
# both ways, and every header of its table is a sort link.
RSpec.describe "Sorting every list" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer, person: create(:person, zone: create(:zone))) }
  let(:daily) { create(:payroll, starts_on: Time.zone.today - 10) }
  let(:task_payroll) { create(:payroll, kind: "task", starts_on: Time.zone.today - 10) }
  let(:hauler) { create(:hauler) }
  let(:buyer) { create(:buyer) }

  def page = Nokogiri::HTML(response.body)

  before do
    purchase = create(:purchase, producer:)
    create(:purchase, producer:, hauler:)
    create(:hauler_payment, hauler:, amount: 10)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call
    create(:loan, person: producer.person)
    create(:supply)
    create(:farm, producer:)
    create(:payroll_member, payroll: daily)
    create(:payroll_expense, payroll: daily)
    PayrollTask.create!(payroll: task_payroll, name: "Chapia", amount: 1_000)
    create(:sale, buyer:)
    create(:shipment, buyer:)
    create(:warehouse_transfer, net_weight: 1)
    create(:expense)
    create(:other_income)
    create(:staff_member)
    create(:shipment, buyer:, carrier: create(:carrier), truck: create(:truck))
    create(:coffee_conversion, :finished)
    sign_in admin
  end

  LISTS = {
    ZoneFilter => -> { trading_zones_path },
    PersonFilter => -> { administration_people_path },
    UserFilter => -> { administration_users_path },
    AuditEventFilter => -> { administration_audit_events_path },
    ProducerFilter => -> { trading_producers_path },
    HaulerFilter => -> { trading_haulers_path },
    HaulerPurchaseFilter => -> { trading_hauler_path(hauler) },
    SupplyFilter => -> { loans_supplies_path },
    FarmFilter => -> { farms_farms_path },
    CreditAccountFilter => -> { loans_credit_accounts_path },
    PurchaseFilter => -> { trading_purchases_path(from: "", to: "") },
    ProducerPurchaseFilter => -> { trading_producer_path(producer, tab: "purchases") },
    InvoiceFilter => -> { trading_invoices_path },
    ProducerInvoiceFilter => -> { trading_producer_path(producer, tab: "invoices") },
    LoanFilter => -> { loans_loans_path },
    PayrollFilter => -> { farms_payrolls_path },
    PayrollPeriodFilter => -> { farms_payroll_path(daily, tab: "periods") },
    PayrollMemberFilter => -> { farms_payroll_path(daily, tab: "members") },
    PayrollLoanFilter => -> { farms_payroll_path(daily, tab: "loans") },
    PayrollTaskFilter => -> { farms_payroll_path(task_payroll, tab: "tasks") },
    PayrollExpenseFilter => -> { farms_payroll_path(daily, tab: "expenses") },
    ShipmentFilter => -> { sales_shipments_path },
    SaleFilter => -> { sales_sales_path },
    BuyerFilter => -> { sales_buyers_path },
    BuyerSaleFilter => -> { sales_buyer_path(buyer, tab: "sales") },
    BuyerShipmentFilter => -> { sales_buyer_path(buyer, tab: "shipments") },
    StockLedgerFilter => -> { sales_stock_path },
    CoffeeConversionFilter => -> { sales_coffee_conversions_path },
    MovementFilter => -> { finance_movements_path(from: "", to: "") },
    IncomeFilter => -> { finance_incomes_path(from: "", to: "") },
    StaffMemberFilter => -> { finance_staff_members_path },
    CarrierFilter => -> { sales_carriers_path },
    TruckFilter => -> { sales_trucks_path },
    WarehouseFilter => -> { sales_warehouses_path },
    WarehouseTransferFilter => -> { sales_warehouse_transfers_path },
    StaffRoleFilter => -> { finance_staff_roles_path },
    ExpenseFilter => -> { finance_expenses_path(from: "", to: "") },
    FinanceCategoryFilter => -> { finance_categories_path },
    ConsolidationFilter => -> { finance_consolidation_path }
  }.freeze

  it "covers every list filter" do
    names = Dir[Rails.root.join("app/models/*_filter.rb")].map { File.basename(it, ".rb").camelize } -
            %w[ListFilter ExpenseCategoryFilter MoneyAccountFilter] # cards only, no table
    expect(LISTS.keys.map(&:name)).to match_array(names)
  end

  LISTS.each do |filter_class, path|
    it "sorts #{filter_class.name.delete_suffix("Filter")} by each of its columns, both ways" do
      base = instance_exec(&path)
      get base
      expect(response).to have_http_status(:ok)

      table = page.css("table.data-table").find { |candidate| candidate.at_css("th a.sort-link") }
      headers = table.css("thead th").reject { it["class"].to_s.match?(/cell-actions|cell-select/) }
      expect(headers).to all(satisfy { it.at_css("a.sort-link") }), "headers without sort: #{headers.reject { it.at_css("a.sort-link") }.map(&:text)}"

      filter_class.sortings.each_key do |key|
        %w[asc desc].each do |dir|
          get "#{base}#{base.include?("?") ? "&" : "?"}sort=#{key}&dir=#{dir}"
          expect(response).to have_http_status(:ok), "#{key} #{dir}: #{response.status}"
        end
      end
    end
  end

  it "marks the column sorted by and offers the next order" do
    get trading_zones_path(sort: "name", dir: "asc")
    header = page.at_css("th[aria-sort=ascending]")
    expect(header.text).to include("Nombre", "▲")
    link = header.at_css("a")
    expect(link["href"]).to include("sort=name", "dir=desc")
    expect(link["data-turbo-frame"]).to eq("zones-list")
    expect(link["data-turbo-action"]).to eq("advance")

    get trading_zones_path(sort: "name", dir: "desc")
    expect(page.at_css("th[aria-sort=descending] a")["href"]).not_to include("sort=")
  end
end
