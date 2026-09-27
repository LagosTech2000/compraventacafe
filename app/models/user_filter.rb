class UserFilter < ListFilter
  field :q, :text
  field :role, :choice, in: %w[admin regular]
  field :status, :choice, in: %w[active inactive]

  def apply(scope)
    scope = scope.where("email_address ILIKE ?", like(q)) if q
    scope = scope.where(admin: role == "admin") if role
    scope = scope.where(active: status == "active") if status
    scope.order(active: :desc, email_address: :asc)
  end
end
