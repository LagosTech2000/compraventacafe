# Suggested reports: a report with its filters already set for a question
# the owner asks often ("¿Qué facturas faltan por pagar?"). Picked from a
# list; the user can change any filter afterwards. Names live in es.yml
# under reports.presets.
class ReportPreset
  attr_reader :key, :report_key, :params

  def self.all
    @all ||= DEFINITIONS.map { |key, (report_key, params)| new(key, report_key, params) }
  end

  def initialize(key, report_key, params)
    @key = key
    @report_key = report_key
    @params = params
  end

  def report_class = Report.find(report_key)
  def title = I18n.t("reports.presets.#{key}")

  DEFINITIONS = {
    purchases_today: [ "purchases", { period: "today" } ],
    purchases_today_by_producer: [ "purchases", { period: "today", group: "producer" } ],
    purchases_week_by_day: [ "purchases", { period: "this_week", group: "day" } ],
    purchases_season_by_month: [ "purchases", { period: "this_season", group: "month" } ],
    purchases_season_by_producer: [ "purchases", { period: "this_season", group: "producer" } ],
    purchases_month_by_zone: [ "purchases", { period: "this_month", group: "zone" } ],
    purchases_month_by_state: [ "purchases", { period: "this_month", group: "coffee_state" } ],
    purchases_uninvoiced: [ "purchases", { period: "all", invoice_status: "uninvoiced", sort: "purchased_at", dir: "asc" } ],
    invoices_pending: [ "invoices", { period: "all", payment_status: "unpaid", sort: "issued_on", dir: "asc" } ],
    invoices_partial: [ "invoices", { period: "all", payment_status: "partial", sort: "balance", dir: "desc" } ],
    invoices_paid_month: [ "invoices", { period: "this_month", payment_status: "paid" } ],
    producers_season_ranking: [ "producers", { period: "this_season", activity: "with_purchases", sort: "quintals" } ],
    producers_inactive: [ "producers", { period: "last_30_days", activity: "without_purchases", sort: "last_purchase_on" } ],
    shipments_in_transit: [ "shipments", { period: "all", status: "in_transit", sort: "departed_at", dir: "asc" } ],
    shipments_over_tolerance: [ "shipments", { period: "this_season", over_tolerance: "1", sort: "difference_percent", dir: "asc" } ],
    shipments_season_by_buyer: [ "shipments", { period: "this_season", group: "buyer" } ],
    sales_unpaid: [ "sales", { period: "all", payment_status: "unpaid", sort: "sold_on", dir: "asc" } ],
    sales_season_by_buyer: [ "sales", { period: "this_season", group: "buyer" } ],
    sales_season_by_month: [ "sales", { period: "this_season", group: "month" } ],
    coffee_stock_month: [ "coffee_stock", { period: "this_month", group: "day" } ],
    coffee_stock_season_by_state: [ "coffee_stock", { period: "this_season", group: "coffee_state" } ],
    loans_overdue: [ "loans", { period: "all", status: "overdue", sort: "due_on", dir: "asc" } ],
    loans_due_soon: [ "loans", { period: "all", status: "active", due: "next_30_days", sort: "due_on", dir: "asc" } ],
    loans_portfolio_by_person: [ "loans", { period: "all", status: "unpaid", group: "person" } ],
    loan_payments_month: [ "loan_payments", { period: "this_month" } ],
    loan_payments_season_by_method: [ "loan_payments", { period: "this_season", group: "payment_method" } ],
    loan_supplies_season: [ "loan_supplies", { period: "this_season", group: "supply" } ],
    payroll_payments_month_by_farm: [ "payroll_payments", { period: "this_month", group: "farm" } ],
    payroll_lines_month_by_person: [ "payroll_lines", { period: "this_month", group: "person" } ],
    harvest_week_by_day: [ "harvest", { period: "this_week", group: "day" } ],
    harvest_season_by_person: [ "harvest", { period: "this_season", group: "person" } ],
    payroll_expenses_month_by_category: [ "payroll_expenses", { period: "this_month", group: "category" } ],
    farms_season_per_manzana: [ "farms", { period: "this_season", sort: "quintals_per_manzana" } ],
    farms_season_balance: [ "farms", { period: "this_season", sort: "balance", dir: "asc" } ],
    people_season: [ "people", { period: "this_season" } ],
    expenses_month_by_category: [ "expenses", { period: "this_month", group: "category" } ],
    investments_season: [ "expenses", { period: "this_season", kind: "investment" } ],
    expenses_season_by_month: [ "expenses", { period: "this_season", group: "month" } ],
    cash_movements_month_by_account: [ "cash_movements", { period: "this_month", group: "account_id" } ],
    cash_movements_week: [ "cash_movements", { period: "this_week", group: "day" } ],
    cash_movements_month_by_source: [ "cash_movements", { period: "this_month", group: "source" } ]
  }.freeze
end
