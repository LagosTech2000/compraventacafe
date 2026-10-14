class ZoneFilter < ListFilter
  field :q, :text

  sorts name: text("zones.name")

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope.newest_first
  end
end
