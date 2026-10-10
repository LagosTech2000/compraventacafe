class ProducerFilter < ListFilter
  field :q, :text
  field :kind, :choice, in: Producer::KINDS
  field :zone_id, :id

  def apply(scope)
    scope = scope.where(person_id: Person.search(q).select(:id)) if q
    scope = scope.where(kind:) if kind
    scope = scope.where(zone_id:) if zone_id
    scope.includes(:person, :zone).newest_first
  end
end
