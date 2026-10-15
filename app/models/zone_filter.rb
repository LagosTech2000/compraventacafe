class ZoneFilter < ListFilter
  field :q, :text

  sorts name: text("zones.name"),
        people: "(SELECT COUNT(*) FROM people WHERE people.zone_id = zones.id)",
        purchases: "(SELECT COUNT(*) FROM purchases WHERE purchases.zone_id = zones.id AND purchases.voided_at IS NULL)"

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope.newest_first
  end
end
