class FarmFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.includes(:department, :municipality).newest_first
  end
end
