class ProducerFilter < ListFilter
  field :q, :text
  field :kind, :choice, in: Producer::KINDS
  field :zone_id, :id

  def apply(scope)
    scope = scope.where(person_id: Person.search(q).select(:id)).or(scope.where("producers.ihcafe_code ILIKE ?", "%#{Producer.sanitize_sql_like(q)}%")) if q
    scope = scope.where(kind:) if kind
    scope = scope.where(person_id: Person.where(zone_id:).select(:id)) if zone_id
    scope.includes(:person, :zone, :farms).newest_first
  end
end
