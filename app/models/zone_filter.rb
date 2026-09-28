class ZoneFilter < ListFilter
  field :q, :text

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope.newest_first
  end
end
