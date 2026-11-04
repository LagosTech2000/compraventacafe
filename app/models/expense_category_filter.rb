class ExpenseCategoryFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("expense_categories.name"),
        parent: { sql: "COALESCE(parents_expense_categories.name, expense_categories.name)", joins: :parent }

  # A search finds a subcategory by its own name or by its first level's.
  def apply(scope)
    scope = scope.left_joins(:parent).where("expense_categories.name ILIKE :q OR parents_expense_categories.name ILIKE :q", q: like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.includes(:parent).ordered
  end
end
