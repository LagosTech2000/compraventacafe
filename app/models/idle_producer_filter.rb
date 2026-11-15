# «Productores que no venden» in full (Fernando, 2026-11-13): by how long,
# name and zone; the ones that stopped most recently first.
class IdleProducerFilter < ListFilter
  field :days, :choice, in: IdleProducers::DAYS.map(&:to_s), default: IdleProducers::DAYS.first.to_s
  field :q, :text
  field :zone_id, :id

  sorts producer: { sql: text("people.first_names", "people.last_names"), joins: :person },
        zone: { sql: text("zones.name"), joins: { person: :zone } },
        last_purchase: "last_purchases.last_purchased_at",
        days: "NOW() - last_purchases.last_purchased_at"

  def apply(scope)
    scope = scope.merge(IdleProducers.scope(days))
    scope = scope.where(person_id: Person.picker_search(q).select(:id)) if q
    scope = scope.where(person_id: Person.where(zone_id:).select(:id)) if zone_id
    scope.includes(person: %i[zone photo_info]).order("last_purchases.last_purchased_at DESC", "producers.id DESC")
  end
end
