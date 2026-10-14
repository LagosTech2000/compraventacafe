class ProducerFilter < ListFilter
  field :q, :text
  field :kind, :choice, in: Producer::KINDS
  field :zone_id, :id

  sorts name: { sql: text("people.first_names", "people.last_names"), joins: :person },
        kind: "producers.kind",
        zone: { sql: text("zones.name"), joins: { person: :zone } },
        ihcafe_code: "producers.ihcafe_code",
        farms: { ruby: ->(producer) { producer.farm_names } },
        phone: { sql: "people.phone", joins: :person },
        season_quintals: { sql: -> { "(SELECT SUM(net_weight) FROM purchases WHERE purchases.producer_id = producers.id " \
                                     "AND purchases.voided_at IS NULL AND purchases.season_year = #{Season.current.year.to_i})" } },
        last_purchase: "(SELECT MAX(purchased_at) FROM purchases WHERE purchases.producer_id = producers.id AND purchases.voided_at IS NULL)"

  def apply(scope)
    scope = scope.where(person_id: Person.search(q).select(:id)).or(scope.where("producers.ihcafe_code ILIKE ?", "%#{Producer.sanitize_sql_like(q)}%")) if q
    scope = scope.where(kind:) if kind
    scope = scope.where(person_id: Person.where(zone_id:).select(:id)) if zone_id
    scope.includes(:person, :zone, :farms).newest_first
  end
end
