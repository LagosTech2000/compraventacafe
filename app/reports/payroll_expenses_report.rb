# Expenses of the farms' payrolls in the period, by category (first level
# and subcategory), farm and payroll.
class PayrollExpensesReport < Report
  TOP_CATEGORY = "COALESCE(parents_expense_categories.id, expense_categories.id)".freeze
  TOP_CATEGORY_NAME = "MIN(COALESCE(parents_expense_categories.name, expense_categories.name))".freeze

  self.module_key = "farms"
  self.date_column = "payroll_expenses.spent_on"
  self.default_period = "this_month"
  self.default_sort = :spent_on
  self.default_measure = :amount

  filter :q, :text
  filter :farm_id, :id
  filter :payroll_id, :id
  filter :category_id, :id

  column(:spent_on, :date, sort: "payroll_expenses.spent_on")
  column(:farm, :text, sort: "farms.name", priority: 2) { |expense| expense.payroll.farm.name }
  column(:payroll, :text, sort: "payrolls.name", priority: 3) { |expense| expense.payroll.name }
  column(:category, :text, sort: ExpenseCategory::FULL_NAME_SQL) { |expense| expense.category.full_name }
  column(:description, :text, sort: "payroll_expenses.description", priority: 2)
  column(:amount, :money, sort: "payroll_expenses.amount")
  column(:created_by, :text, sort: "users.name", priority: 3) { |expense| expense.created_by.name }

  measure :count, :integer, "COUNT(*)"
  measure :amount, :money, "SUM(payroll_expenses.amount)"
  measure :average, :money, "AVG(payroll_expenses.amount)"

  group :week, unit: "week"
  group :month, unit: "month"
  group :category, sql: TOP_CATEGORY, label_sql: TOP_CATEGORY_NAME
  group :subcategory, sql: "payroll_expenses.expense_category_id", label_sql: "MIN(#{ExpenseCategory::FULL_NAME_SQL})"
  group :farm, sql: "payrolls.farm_id", label_sql: "MIN(farms.name)"
  group :payroll, sql: "payroll_expenses.payroll_id", label_sql: "MIN(payrolls.name || ' · ' || farms.name)"

  kpi :amount, :money, "SUM(payroll_expenses.amount)", good: :down
  kpi :count, :integer, "COUNT(*)"
  kpi :average, :money, "AVG(payroll_expenses.amount)", good: :down
  kpi :categories, :integer, "COUNT(DISTINCT #{TOP_CATEGORY})"

  def scope
    PayrollExpense.joins(:category, :created_by, payroll: :farm).left_joins(category: :parent)
  end

  def apply_filters(relation)
    relation = relation.where("payroll_expenses.description ILIKE ?", like(filter.q)) if filter.q
    relation = relation.where(payrolls: { farm_id: filter.farm_id }) if filter.farm_id
    relation = relation.where(payroll_id: filter.payroll_id) if filter.payroll_id
    relation = relation.where("#{TOP_CATEGORY} = :id OR payroll_expenses.expense_category_id = :id", id: filter.category_id) if filter.category_id
    relation
  end

  def charts
    relation = records
    categories = breakdown(relation, TOP_CATEGORY, "SUM(payroll_expenses.amount)", label_sql: TOP_CATEGORY_NAME)
    labels, by_category = over_time_by(relation, TOP_CATEGORY, "SUM(payroll_expenses.amount)", label_sql: TOP_CATEGORY_NAME)
    farms = breakdown(relation, "payrolls.farm_id", "SUM(payroll_expenses.amount)", label_sql: "MIN(farms.name)")
    payrolls = breakdown(relation, "payroll_expenses.payroll_id", "SUM(payroll_expenses.amount)",
                         label_sql: "MIN(payrolls.name || ' · ' || farms.name)", limit: 10, others: false)

    [
      chart(:categories, :doughnut, labels: categories.map(&:first), datasets: [ dataset(:amount, categories.map(&:last), format: :money) ]),
      chart(:over_time, :stacked, labels:, datasets: by_category.map { |set| set.merge(format: :money) }),
      chart(:farms, :hbar, labels: farms.map(&:first), datasets: [ dataset(:amount, farms.map(&:last), format: :money) ]),
      chart(:payrolls, :hbar, labels: payrolls.map(&:first), datasets: [ dataset(:amount, payrolls.map(&:last), format: :money) ]),
      locations(:map, relation, place: :farm, measure: :amount, sql: "SUM(payroll_expenses.amount)", format: :money,
                                link: :farms_farm_path, link_sql: "farms.id")
    ]
  end

  private
    def preload(relation) = relation.includes({ category: :parent }, :created_by, payroll: :farm)
end
