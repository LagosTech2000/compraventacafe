class PayrollExpenseFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :expense_category_id, :id

  sorts spent_on: "payroll_expenses.spent_on", category: { sql: ExpenseCategory::FULL_NAME_SQL, joins: { category: :parent } },
        description: text("payroll_expenses.description"), amount: "payroll_expenses.amount"

  def apply(scope)
    scope = scope.where(spent_on: from..) if from
    scope = scope.where(spent_on: ..to) if to
    scope = scope.where("description ILIKE ?", like(q)) if q
    scope = scope.where(expense_category_id: ExpenseCategory.family_ids(expense_category_id)) if expense_category_id
    scope.includes(category: :parent).newest_first
  end
end
