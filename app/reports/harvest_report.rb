# Coffee picked: cans per picker per day in the harvest payrolls, how many
# pickers came and what it is worth at each payroll's can price.
class HarvestReport < Report
  NAME = "people.first_names || ' ' || people.last_names".freeze
  VALUE = "harvest_entries.cans * payrolls.can_price".freeze

  self.module_key = "farms"
  self.date_column = "harvest_entries.worked_on"
  self.default_period = "this_week"
  self.default_sort = :worked_on
  self.default_measure = :cans

  filter :q, :text
  filter :farm_id, :id
  filter :payroll_id, :id

  column(:worked_on, :date, sort: "harvest_entries.worked_on")
  column(:person, :text, sort: "people.last_names") { |entry| entry.member.full_name }
  column(:farm, :text, sort: "farms.name", priority: 3) { |entry| entry.member.payroll.farm.name }
  column(:payroll, :text, sort: "payrolls.name", priority: 2) { |entry| entry.member.payroll.name }
  column(:cans, :number, sort: "harvest_entries.cans")
  column(:can_price, :money, sort: "payrolls.can_price", priority: 3) { |entry| entry.member.payroll.can_price }
  column(:value, :money, sort: VALUE) { |entry| (entry.cans * entry.member.payroll.can_price.to_d).round(2) }

  measure :cans, :number, "SUM(harvest_entries.cans)"
  measure :pickers, :integer, "COUNT(DISTINCT payroll_members.person_id)"
  measure :days, :integer, "COUNT(DISTINCT harvest_entries.worked_on)"
  measure :average, :number, "SUM(harvest_entries.cans) / COUNT(*)"
  measure :value, :money, "SUM(#{VALUE})"

  group :day, unit: "day"
  group :week, unit: "week"
  group :month, unit: "month"
  group :person, sql: "payroll_members.person_id", label_sql: "MIN(#{NAME})"
  group :farm, sql: "payrolls.farm_id", label_sql: "MIN(farms.name)"
  group :payroll, sql: "payroll_members.payroll_id", label_sql: "MIN(payrolls.name || ' · ' || farms.name)"

  kpi :cans, :number, "SUM(harvest_entries.cans)", good: :up
  kpi :value, :money, "SUM(#{VALUE})"
  kpi :pickers, :integer, "COUNT(DISTINCT payroll_members.person_id)", good: :up
  kpi :days, :integer, "COUNT(DISTINCT harvest_entries.worked_on)"
  kpi :average, :number, "SUM(harvest_entries.cans) / NULLIF(COUNT(*), 0)", good: :up
  kpi(:best_day, :number) { |relation, _| relation.group(:worked_on).sum(:cans).values.max }

  def scope
    HarvestEntry.joins(member: [ :person, { payroll: :farm } ])
  end

  def apply_filters(relation)
    relation = relation.where(payroll_members: { person_id: people_matching(filter.q) }) if filter.q
    relation = relation.where(payrolls: { farm_id: filter.farm_id }) if filter.farm_id
    relation = relation.where(payroll_members: { payroll_id: filter.payroll_id }) if filter.payroll_id
    relation
  end

  def charts
    relation = records
    labels, daily = over_time(relation, { cans: "SUM(harvest_entries.cans)", pickers: "COUNT(DISTINCT payroll_members.person_id)" })
    average_labels, averages = over_time(relation, { average: "SUM(harvest_entries.cans) / COUNT(*)" }, gaps: nil)
    top = breakdown(relation, "payroll_members.person_id", "SUM(harvest_entries.cans)", label_sql: "MIN(#{NAME})", limit: 15, others: false)
    farms = breakdown(relation, "payrolls.farm_id", "SUM(harvest_entries.cans)", label_sql: "MIN(farms.name)")

    [
      chart(:cans, :combo, labels:, datasets: [ dataset(:cans, daily[:cans], format: :number),
                                                dataset(:pickers, daily[:pickers], format: :integer, kind: :line, axis: :y2) ], wide: true),
      chart(:top, :hbar, labels: top.map(&:first), datasets: [ dataset(:cans, top.map(&:last), format: :number) ]),
      chart(:average, :line, labels: average_labels, datasets: [ dataset(:average, averages[:average], format: :number) ]),
      chart(:farms, :doughnut, labels: farms.map(&:first), datasets: [ dataset(:cans, farms.map(&:last), format: :number) ]),
      locations(:map, relation, place: :farm, measure: :cans, sql: "SUM(harvest_entries.cans)", format: :number,
                                link: :farms_farm_path, link_sql: "farms.id")
    ]
  end

  private
    def preload(relation) = relation.includes(member: [ :person, { payroll: :farm } ])
end
