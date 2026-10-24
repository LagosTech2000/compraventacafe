# Expenses and investments of Control financiero: by category (first level
# and subcategory), account, payee and month, against the budget of the
# months of the period.
class ExpensesReport < Report
  TOP_CATEGORY = "COALESCE(parents_finance_categories.id, finance_categories.id)".freeze
  TOP_CATEGORY_NAME = "MIN(COALESCE(parents_finance_categories.name, finance_categories.name))".freeze

  self.module_key = "finance"
  self.date_column = "expenses.spent_on"
  self.default_period = "this_month"
  self.default_sort = :spent_on
  self.default_measure = :amount

  filter :q, :text
  filter :kind, :choice, in: Expense::KINDS
  filter :category_id, :id
  filter :money_account_id, :id
  filter :payment_method, :choice, in: Invoice::PAYMENT_METHODS

  detail { |expense| expense.investment? ? finance_investment_path(expense) : finance_expense_path(expense) }

  column(:spent_on, :date, sort: "expenses.spent_on")
  column(:kind, :text, sort: "expenses.kind", priority: 2, &:human_kind)
  column(:description, :text, sort: "expenses.description")
  column(:category, :text, sort: "finance_categories.name") { |expense| expense.category.full_name }
  column(:payee, :text, sort: "expenses.payee", priority: 2)
  column(:account, :text, sort: "money_accounts.name", priority: 3) { |expense| expense.money_account.name }
  column(:payment_method, :text, sort: "expenses.payment_method", priority: 3, &:human_payment_method)
  column(:receipt_number, :text, sort: "expenses.receipt_number", priority: 3)
  column(:amount, :money, sort: "expenses.amount")

  measure :count, :integer, "COUNT(*)"
  measure :amount, :money, "SUM(expenses.amount)"
  measure :average, :money, "AVG(expenses.amount)"

  group :week, unit: "week"
  group :month, unit: "month"
  group :category, sql: TOP_CATEGORY, label_sql: TOP_CATEGORY_NAME
  group :subcategory, sql: "expenses.finance_category_id",
                      label_sql: "MIN(CONCAT_WS(' › ', parents_finance_categories.name, finance_categories.name))"
  group :kind, sql: "expenses.kind", translate: ->(kind) { Expense.human_attribute_name("kind/#{kind}") }
  group :account_id, sql: "expenses.money_account_id", label_sql: "MIN(money_accounts.name)"
  group :payee, sql: "COALESCE(expenses.payee, '')", translate: ->(payee) { payee.presence || I18n.t("reports.none") }
  group :payment_method, sql: "expenses.payment_method", translate: ->(method) { Invoice.human_attribute_name("payment_method/#{method}") }

  kpi :amount, :money, "SUM(expenses.amount)", good: :down
  kpi :expenses, :money, "COALESCE(SUM(expenses.amount) FILTER (WHERE expenses.kind = 'expense'), 0)", good: :down
  kpi :investments, :money, "COALESCE(SUM(expenses.amount) FILTER (WHERE expenses.kind = 'investment'), 0)"
  kpi :count, :integer, "COUNT(*)"
  # The budget of the months the period touches (first-level categories).
  kpi(:budget, :money, compare: false) { |_, in_period| budget_of(in_period) }
  kpi(:budget_used, :percent, compare: false) do |records, in_period|
    budget = budget_of(in_period)
    budget.positive? ? (records.sum("expenses.amount") * 100 / budget).round(1) : nil
  end

  def scope
    Expense.joins(:money_account).joins(:category).left_joins(category: :parent)
  end

  def apply_filters(relation)
    relation = relation.where("expenses.description ILIKE :q OR expenses.payee ILIKE :q OR expenses.receipt_number ILIKE :q", q: like(filter.q)) if filter.q
    relation = relation.where(kind: filter.kind) if filter.kind
    relation = relation.where("#{TOP_CATEGORY} = :id OR expenses.finance_category_id = :id", id: filter.category_id) if filter.category_id
    relation = relation.where(money_account_id: filter.money_account_id) if filter.money_account_id
    relation = relation.where(payment_method: filter.payment_method) if filter.payment_method
    relation
  end

  def charts
    relation = records
    kinds = human(Expense, :kind)
    labels, by_kind = over_time_by(relation, "expenses.kind", "SUM(expenses.amount)", translate: kinds)
    categories = breakdown(relation, TOP_CATEGORY, "SUM(expenses.amount)", label_sql: TOP_CATEGORY_NAME)
    payees = breakdown(relation, "COALESCE(expenses.payee, '')", "SUM(expenses.amount)", translate: ->(payee) { payee.presence || I18n.t("reports.none") },
                                                                                            others: false)
    pareto_labels, pareto_values, shares = pareto(payees, payees.sum(&:last))
    accounts = breakdown(relation, "expenses.money_account_id", "SUM(expenses.amount)", label_sql: "MIN(money_accounts.name)")

    [
      chart(:over_time, :stacked, labels:, datasets: by_kind.map { |set| set.merge(format: :money) }, wide: true),
      chart(:categories, :doughnut, labels: categories.map(&:first), datasets: [ dataset(:amount, categories.map(&:last), format: :money) ]),
      chart(:payees, :combo, labels: pareto_labels, datasets: [ dataset(:amount, pareto_values, format: :money),
                                                               dataset(:share, shares, format: :percent, kind: :line, axis: :y2) ]),
      chart(:accounts, :hbar, labels: accounts.map(&:first), datasets: [ dataset(:amount, accounts.map(&:last), format: :money) ])
    ]
  end

  private
    def budget_of(in_period)
      range = in_period&.range
      budgets = Budget.all
      budgets = budgets.where(month: (range.begin&.beginning_of_month)..(range.end)) if range
      budgets = budgets.where(finance_category_id: FinanceCategory.find_by(id: filter.category_id)&.root&.id) if filter.category_id
      budgets = budgets.where(finance_category_id: FinanceCategory.top_level.where(kind: filter.kind).select(:id)) if filter.kind
      budgets.sum(:amount)
    end

    def preload(relation)
      relation.includes(:money_account, category: :parent)
    end
end
