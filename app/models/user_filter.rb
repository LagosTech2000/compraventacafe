class UserFilter < ListFilter
  field :q, :text
  field :role, :choice, in: %w[admin regular]
  field :status, :choice, in: %w[active inactive]

  def apply(scope)
    scope = scope.where("name ILIKE :q OR email_address ILIKE :q", q: like(q)) if q
    scope = scope.where(admin: role == "admin") if role
    scope = scope.where(active: status == "active") if status
    scope.newest_first
  end
end
