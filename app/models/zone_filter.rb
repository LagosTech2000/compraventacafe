class ZoneFilter < ListFilter
  field :q, :text

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope.ordered
  end
end
