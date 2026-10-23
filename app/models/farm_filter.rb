class FarmFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  # Whose: the business's own farms or the producers' (Fernando, 2026-10-18).
  OWNERS = %w[business producers].freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"
  field :owner, :choice, in: OWNERS

  sorts name: text("farms.name"),
        owner: { sql: text("people.first_names", "people.last_names"), joins: { producer: :person } },
        location: { sql: text("departments.name", "municipalities.name", "farms.address_line"), joins: %i[department municipality] },
        area: FarmArea.square_meters_sql,
        status: "NOT farms.active"

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope = owner == "business" ? scope.of_business : scope.where.not(producer_id: nil) if owner
    scope.includes(:department, :municipality, producer: :person).newest_first
  end
end
