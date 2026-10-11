class PayrollExpenseFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :expense_category_id, :id

  def apply(scope)
    scope = scope.where(spent_on: from..) if from
    scope = scope.where(spent_on: ..to) if to
    scope = scope.where("description ILIKE ?", like(q)) if q
    scope = scope.where(expense_category_id:) if expense_category_id
    scope.includes(:category).newest_first
  end
end
