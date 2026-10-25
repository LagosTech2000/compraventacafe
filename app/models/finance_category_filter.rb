class FinanceCategoryFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :kind, :choice, in: FinanceCategory::KINDS
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("finance_categories.name"), kind: "finance_categories.kind",
        parent: { sql: "COALESCE(parents_finance_categories.name, finance_categories.name)", joins: :parent }

  def apply(scope)
    scope = scope.left_joins(:parent).where("finance_categories.name ILIKE :q OR parents_finance_categories.name ILIKE :q", q: like(q)) if q
    scope = scope.where(kind:) if kind
    scope = scope.where(active: status == "active") if status
    scope.includes(:parent).order(Arel.sql("COALESCE(finance_categories.parent_id, finance_categories.id), finance_categories.parent_id NULLS FIRST, finance_categories.name"))
  end
end
