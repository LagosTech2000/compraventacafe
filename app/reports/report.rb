# A report: the records of one kind (purchases, loans, payroll payments...)
# narrowed by filters, shown as a table that loads page by page, summed up
# in figures (KPIs) compared with the period before, and drawn in charts.
# Everything is computed by the database from the filtered records, not from
# the rows on screen.
#
# A report declares, with the class methods below:
#
#   filter   its own filter fields (the period, sort and grouping are common)
#   column   the columns of the detail table
#   measure  what a grouped table sums or averages per group
#   group    the ways to group ("Agrupar por": month, producer, zone...)
#   kpi      the figures on top
#
# and defines #scope (the records it reads, joined as needed),
# #apply_filters and #charts. A report reads one module's data and needs
# its read permission (module_key), besides the reports module's; a report
# that crosses modules says which (see ReportPolicy).
class Report
  PER_PAGE = 50
  CSV_LIMIT = 50_000
  # Bars or slices shown before the rest goes to "Otros".
  TOP = 12
  # Where a map chart puts each record (see #locations).
  PLACES = {
    person: { id: "people.id", label: "people.first_names || ' ' || people.last_names",
              latitude: "people.latitude", longitude: "people.longitude" },
    farm: { id: "farms.id", label: "farms.name", latitude: "farms.latitude", longitude: "farms.longitude" }
  }.freeze

  Column = Data.define(:key, :type, :sort, :priority, :value, :label)
  Measure = Data.define(:key, :type, :sql)
  Grouping = Data.define(:key, :sql, :label_sql, :unit, :translate)
  KpiDefinition = Data.define(:key, :type, :sql, :block, :good, :compare)
  Kpi = Data.define(:key, :type, :value, :previous, :good) do
    # Change against the previous period, as a fraction (0.12 = +12 %).
    def change
      return if previous.nil? || value.nil? || previous.to_d.zero?

      (value.to_d - previous.to_d) / previous.to_d.abs
    end
  end
  Chart = Data.define(:key, :type, :labels, :datasets, :options)
  # A row of a grouped table: the group's key and label, and its measures.
  GroupRow = Struct.new(:key, :label, :values) do
    def [](name) = values[name.to_s]
  end

  # default_sort: the detail column sorted by (newest first);
  # default_measure: the one grouped tables are sorted by (largest first),
  # except time groups, newest first.
  class_attribute :module_key, :date_column, :default_period, :default_sort, :default_measure, :filter_class,
                  instance_writer: false
  class_attribute :date_type, default: :date, instance_writer: false
  # Path of a record's detail, run in the view (see .detail).
  class_attribute :detail_route, instance_writer: false
  class_attribute :columns, :measures, :groupings, :kpi_definitions, default: [], instance_writer: false

  def self.inherited(subclass)
    super
    subclass.filter_class = Class.new(ReportFilter) do
      field :period, :text, default: -> { subclass.default_period }
    end
    subclass.prepend(CachedCharts)
  end

  # Each report's #charts, from the cache when nothing changed (see #cached).
  module CachedCharts
    def charts = cached(:charts) { super }
  end

  # Reports in the order the picker lists them.
  def self.catalog
    [ PurchasesReport, InvoicesReport, ProducersReport,
      ShipmentsReport, SalesReport, CoffeeStockReport,
      LoansReport, LoanPaymentsReport, LoanSuppliesReport,
      PayrollPaymentsReport, PayrollLinesReport, HarvestReport, PayrollExpensesReport, FarmsReport,
      ExpensesReport,
      PeopleReport, CashMovementsReport ]
  end

  def self.find(key) = catalog.find { |report| report.key == key.to_s }
  def self.key = name.delete_suffix("Report").underscore
  def self.title = I18n.t("reports.types.#{key}.title")
  def self.description = I18n.t("reports.types.#{key}.description")
  def self.policy_class = ReportPolicy
  # Modules whose read permission the report needs. Cross-module reports
  # override it.
  def self.module_keys = [ module_key ]

  # --- Declarations ---------------------------------------------------------

  def self.filter(name, type, **options)
    filter_class.field(name, type, **options)
  end

  # value: what to show for a record (by default, the attribute of the same
  # name). priority 1 shows on every width, 2 from medium, 3 only on wide.
  def self.column(key, type, sort: nil, priority: 1, &value)
    self.columns = columns + [ Column.new(key:, type:, sort:, priority:, value: value || key.to_proc, label: nil) ]
  end

  def self.measure(key, type, sql)
    self.measures = measures + [ Measure.new(key:, type:, sql:) ]
  end

  # unit: a date part for time groups (day, week, month); otherwise sql is
  # the key, label_sql its name (optional) and translate turns a stored
  # value into words (coffee state, status...).
  def self.group(key, sql: nil, label_sql: nil, unit: nil, translate: nil)
    self.groupings = groupings + [ Grouping.new(key:, sql:, label_sql:, unit:, translate:) ]
  end

  # sql: an aggregate over the filtered records, or a block that gets them.
  # good: :up or :down, which way of change is good news (colors the
  # comparison). compare: false for figures that are a snapshot of today.
  def self.kpi(key, type, sql = nil, good: nil, compare: true, &block)
    self.kpi_definitions = kpi_definitions + [ KpiDefinition.new(key:, type:, sql:, block:, good:, compare:) ]
  end

  # Where a row's "Detalle" button opens, e.g.
  #   detail { |purchase| trading_purchase_path(purchase) }
  def self.detail(&block)
    self.detail_route = block
  end

  # --- Instance -------------------------------------------------------------

  attr_reader :filter, :user, :today

  def initialize(params = {}, user: nil, today: Time.zone.today)
    params = ActionController::Parameters.new(params) unless params.is_a?(ActionController::Parameters)
    @user = user
    @today = today
    @filter = filter_class.new(params)
  end

  def key = self.class.key
  def title = self.class.title
  def module_keys = self.class.module_keys

  def period
    @period ||= ReportPeriod.new(filter.period.presence || default_period, from: filter.from, to: filter.to, today:)
  end

  # Records matching the filters and the period (or another period, to
  # compare).
  def records(in_period = period)
    within(apply_filters(scope), in_period)
  end

  def grouping = groupings.find { |grouping| grouping.key.to_s == filter.group }
  def grouped? = grouping.present?
  def detail? = !grouped? && detail_route.present?

  # Columns of the table: the detail ones, or the group plus its measures.
  def table_columns
    return visible_columns unless grouped?

    [ Column.new(key: :group, type: :group, sort: "group_key", priority: 1, value: :label.to_proc,
                 label: I18n.t("reports.groups.#{grouping.key}")) ] +
      measures.each_with_index.map do |measure, index|
        Column.new(key: measure.key, type: measure.type, sort: measure.key.to_s, priority: index < 3 ? 1 : 2,
                   value: ->(row) { row[measure.key] }, label: nil)
      end
  end

  def column_label(column)
    column.label || I18n.t("reports.types.#{key}.columns.#{column.key}")
  end

  # The key of the column the table is sorted by, and which way.
  def sort_key
    sortable = table_columns.select(&:sort).map { |column| column.key.to_s }
    sortable.include?(filter.sort) ? filter.sort : default_sort_key
  end

  def sort_direction = filter.dir || "desc"

  # [rows of the page, whether there are more].
  def page(number = filter.page)
    relation = grouped? ? grouped_relation : detail_relation
    rows = relation.offset((number - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    more = rows.size > PER_PAGE
    rows = rows.first(PER_PAGE)
    [ grouped? ? rows.map { |record| group_row(record) } : prepare_rows(rows), more ]
  end

  def total_count
    @total_count ||= cached(:total_count) { grouped? ? plain(records).distinct.count(Arel.sql(grouping_sql)) : plain(records).count }
  end

  def kpis
    @kpis ||= cached(:kpis) do
      previous = period.previous
      kpi_definitions.map do |definition|
        current = kpi_value(definition, records, period)
        before = kpi_value(definition, records(previous), previous) if previous && definition.compare
        Kpi.new(key: definition.key, type: definition.type, value: current, previous: before, good: definition.good)
      end
    end
  end

  # Every record of the filters (not paged), for the CSV file.
  def each_row(&)
    relation = grouped? ? grouped_relation : detail_relation
    relation.limit(CSV_LIMIT).each_slice(500) do |slice|
      rows = grouped? ? slice.map { |record| group_row(record) } : prepare_rows(slice)
      rows.each(&)
    end
  end

  # Subclasses return a list of Chart (see the builders below).
  def charts = []

  # Figures, charts and counts come from the cache while the data did not
  # change (Fernando, 2026-10-18: reports always fast). The key has the
  # report, its filters (not the sort or the page, which only order the
  # table), today (periods count from it), the modules the user can see
  # (cross-module reports show what each user may) and DataVersion, which
  # every saved change bumps: a change is never hidden behind an old copy.
  # CACHE_FOR is only a ceiling for what nothing bumps.
  CACHE_FOR = 30.minutes

  def cached(name, &)
    Rails.cache.fetch(cache_key(name), expires_in: CACHE_FOR, &)
  end

  private
    def cache_key(name)
      query = filter.to_params.except("sort", "dir", "page").sort.to_h.to_query
      modules = user && (user.admin? ? "admin" : AppModule::KEYS.select { |key| user.can?(key, :read) }.join(","))
      [ "report", key, name, DataVersion.current, today.iso8601, modules, Digest::SHA256.hexdigest(query) ].join("/")
    end

    def default_sort_key
      return default_sort.to_s unless grouped?

      grouping.unit ? "group" : default_measure.to_s
    end

    def sort_sql = table_columns.find { |column| column.key.to_s == sort_key }.sort

    # Detail columns the user may see (cross-module reports hide columns of
    # modules the user cannot read).
    def visible_columns = columns

    # Rows of a page, before they are shown: load what they need at once.
    def prepare_rows(rows) = rows

    def detail_relation
      order = Arel.sql("#{sort_sql} #{sort_direction.upcase} NULLS LAST, #{scope.klass.quoted_table_name}.id #{sort_direction.upcase}")
      preload(records.reorder(order))
    end

    def preload(relation) = relation

    # A relation for sums and counts: no order, select or preloads.
    def plain(relation) = relation.unscope(:order, :select, :includes, :preload)

    def grouped_relation
      selects = [ "#{grouping_sql} AS group_key" ]
      selects << "#{grouping.label_sql} AS group_label" if grouping.label_sql
      selects += measures.map { |measure| "#{measure.sql} AS #{measure.key}" }
      order = "#{sort_sql} #{sort_direction.upcase} NULLS LAST, group_key ASC"
      plain(records).group(Arel.sql(grouping_sql)).select(*selects.map { |sql| Arel.sql(sql) })
             .reorder(Arel.sql(order))
    end

    def grouping_sql
      grouping.unit ? time_bucket(grouping.unit) : grouping.sql
    end

    def group_row(record)
      values = record.attributes.except("id")
      group_key = values.delete("group_key")
      label = values.delete("group_label")
      GroupRow.new(group_key, group_label(group_key, label), values)
    end

    def group_label(value, label)
      return I18n.t("reports.none") if value.nil?
      return bucket_label(value.to_date, grouping.unit) if grouping.unit
      return grouping.translate.call(value) if grouping.translate

      label.presence || value.to_s
    end

    # A block gets the records and their period: kpi(:x, :money) { |records, period| ... }
    def kpi_value(definition, relation, in_period)
      relation = plain(relation) if relation.respond_to?(:unscope)
      definition.block ? instance_exec(relation, in_period, &definition.block) : relation.pick(Arel.sql(definition.sql))
    end

    # Records of a period by the report's date (or another date column; a
    # timestamp covers whole days in Tegucigalpa time).
    def within(relation, in_period, column: date_column, type: (column == date_column ? date_type : :date))
      range = in_period&.range
      return relation unless range

      from = type == :datetime ? range.begin&.in_time_zone&.beginning_of_day : range.begin
      to = type == :datetime ? range.end&.in_time_zone&.end_of_day : range.end
      relation = relation.where("#{column} >= ?", from) if from
      relation = relation.where("#{column} <= ?", to) if to
      relation
    end

    # --- Dates --------------------------------------------------------------

    # The date of a record in Tegucigalpa time (timestamps are stored in UTC).
    def local_date_sql(column = date_column)
      return column unless date_type == :datetime && column == date_column

      "(#{column} AT TIME ZONE 'UTC' AT TIME ZONE '#{Time.zone.tzinfo.name}')"
    end

    def time_bucket(unit, column = date_column)
      "DATE_TRUNC('#{unit}', #{local_date_sql(column)})::date"
    end

    # Day buckets for short periods, weeks up to half a year, months beyond.
    def bucket_unit(relation = records)
      days = period.length_in_days || data_span_in_days(relation)
      if days <= 45 then "day"
      elsif days <= 190 then "week"
      else "month"
      end
    end

    def data_span_in_days(relation)
      first, last = plain(relation).pick(Arel.sql("MIN(#{local_date_sql})::date"), Arel.sql("MAX(#{local_date_sql})::date"))
      first && last ? (last - first).to_i + 1 : 1
    end

    def bucket_label(date, unit)
      case unit
      when "day" then I18n.l(date, format: :short)
      when "week" then I18n.t("reports.week_of", date: I18n.l(date, format: :short))
      else I18n.l(date, format: :month_year)
      end
    end

    # Every bucket from the first to the last, so days without data show 0.
    def buckets(unit, keys)
      range = period.range
      first = range&.begin || keys.min
      last = [ range&.end, today ].compact.min || keys.max
      return [] unless first && last

      first = first.beginning_of_week if unit == "week"
      first = first.beginning_of_month if unit == "month"
      step = { "day" => 1.day, "week" => 1.week, "month" => 1.month }.fetch(unit)
      dates = []
      date = first
      while date <= last
        dates << date
        date += step
      end
      dates
    end

    # --- Chart builders -----------------------------------------------------

    # Measures over time: { key => sql } → labels and one series each.
    # gaps: what a bucket without data is (0, or nil for averages).
    def over_time(relation, sums, column: date_column, gaps: 0)
      unit = bucket_unit(relation)
      bucket = time_bucket(unit, column)
      data = plain(relation).group(Arel.sql(bucket))
                     .pluck(Arel.sql(bucket), *sums.values.map { |sql| Arel.sql(sql) })
                     .to_h { |date, *values| [ date, values ] }
      dates = buckets(unit, data.keys)
      series = sums.keys.each_with_index.to_h do |name, index|
        [ name, dates.map { |date| (value = data.dig(date, index)).nil? ? gaps : number(value) } ]
      end
      [ dates.map { |date| bucket_label(date, unit) }, series ]
    end

    # One series per category over time (stacked bars): the `limit`
    # categories with the largest total, the rest added up as "Otros".
    # gaps: what a bucket without data is (0 for amounts, nil for averages,
    # which have no "Otros": averages do not add up).
    def over_time_by(relation, category_sql, measure_sql, label_sql: nil, translate: nil, limit: 5, gaps: 0)
      unit = bucket_unit(relation)
      bucket = time_bucket(unit)
      plucks = [ bucket, category_sql, measure_sql ] + [ label_sql ].compact
      rows = plain(relation).group(Arel.sql(bucket), Arel.sql(category_sql))
                     .pluck(*plucks.map { |sql| Arel.sql(sql) })
      labels = rows.to_h { |_, category, _, label| [ category, category_label(category, label, translate) ] }
      totals = rows.each_with_object(Hash.new(0)) { |(_, category, value), sums| sums[category] += value.to_d }
      top = totals.sort_by { |_, total| -total }.first(limit).map(&:first)
      series = Hash.new { |hash, category| hash[category] = {} }
      rows.each do |date, category, value|
        name = top.include?(category) ? category : :others
        next if name == :others && gaps.nil?

        series[name][date] = series[name].fetch(date, 0) + value.to_d
      end
      dates = buckets(unit, rows.map(&:first).uniq)
      datasets = (top + (series.key?(:others) ? [ :others ] : [])).map do |category|
        label = category == :others ? I18n.t("reports.others") : labels[category]
        { label:, category: true, data: dates.map { |date| series[category].key?(date) ? number(series[category][date]) : gaps } }
      end
      [ dates.map { |date| bucket_label(date, unit) }, datasets ]
    end

    # [[label, value], ...] by category, largest first; past `limit` the
    # rest adds up as "Otros" unless others: false.
    def breakdown(relation, category_sql, measure_sql, label_sql: nil, translate: nil, limit: TOP, others: true)
      plucks = [ category_sql, measure_sql ]
      plucks << label_sql if label_sql
      rows = plain(relation).group(Arel.sql(category_sql))
                     .pluck(*plucks.map { |sql| Arel.sql(sql) })
                     .map { |category, value, label| [ category_label(category, label, translate), number(value) ] }
                     .sort_by { |_, value| -value }
      return rows.first(limit) unless others && rows.size > limit

      rows.first(limit) + [ [ I18n.t("reports.others"), number(rows.drop(limit).sum(&:last)) ] ]
    end

    def category_label(category, label, translate)
      return I18n.t("reports.none") if category.nil?
      return translate.call(category) if translate

      (label.presence || category).to_s
    end

    # Bars of the largest first with a line of their accumulated share of the
    # total: few categories carrying most of it show at a glance.
    def pareto(rows, total)
      running = 0
      shares = rows.map { |_, value| (running += value) && (total.to_d.positive? ? (running / total.to_d * 100).round(1).to_f : 0) }
      [ rows.map(&:first), rows.map(&:last), shares ]
    end

    # Where the records happen, on a map (Fernando, 2026-10-13): grouped by
    # the person or farm they belong to that has coordinates (HasAddress), a
    # point each, sized by the measure. `place` says which (PLACES, or its
    # own SQL); `link` names the route of each point's page, called with the
    # value of `link_sql`. Those without a point are counted apart.
    def locations(key, relation, place:, measure:, sql:, format:, link: nil, link_sql: nil)
      place = PLACES.fetch(place) if place.is_a?(Symbol)
      plucks = [ place[:id], "MIN(#{place[:label]})", "MIN(#{place[:latitude]})", "MIN(#{place[:longitude]})", sql ]
      plucks << "MIN(#{link_sql})" if link_sql
      rows = plain(relation).where("#{place[:latitude]} IS NOT NULL AND #{place[:longitude]} IS NOT NULL")
                            .group(Arel.sql(place[:id])).order(Arel.sql("#{sql} DESC"))
                            .pluck(*plucks.map { Arel.sql(it) })
      missing = plain(relation).where("#{place[:latitude]} IS NULL OR #{place[:longitude]} IS NULL").pick(Arel.sql("COUNT(DISTINCT #{place[:id]})"))
      points = rows.map { |row| { latitude: row[2].to_f, longitude: row[3].to_f, link_id: (row[5] if link_sql) } }

      chart(key, :map, labels: rows.map { it[1] }, datasets: [ dataset(measure, rows.map { number(it[4]) }, format:) ],
                       points:, link:, missing: missing.to_i, wide: true)
    end

    # Count of records by weekday × hour, in Tegucigalpa time.
    def weekday_hours(relation)
      local = local_date_sql
      plain(relation)
              .group(Arel.sql("EXTRACT(ISODOW FROM #{local})"), Arel.sql("EXTRACT(HOUR FROM #{local})"))
              .count
              .transform_keys { |weekday, hour| [ weekday.to_i, hour.to_i ] }
    end

    # Records by how many days old they are, in buckets: [[label, value]].
    def age_buckets(values_by_days, edges)
      labels = edges.each_cons(2).map { |from, to| I18n.t("reports.days_range", from:, to: to - 1) } +
               [ I18n.t("reports.days_over", days: edges.last - 1) ]
      sums = Array.new(labels.size, 0)
      values_by_days.each do |days, value|
        index = edges.rindex { |edge| days.to_i >= edge } || 0
        sums[index] += value.to_d
      end
      labels.zip(sums.map { |sum| number(sum) })
    end

    # tones: { label => "danger" / "success" / "muted" } for colors with a
    # meaning (late in red, paid in green).
    def chart(key, type, labels:, datasets:, **options)
      Chart.new(key:, type:, labels:, datasets:, options:)
    end

    def dataset(key, data, format: :number, **options)
      { label: I18n.t("reports.types.#{self.key}.series.#{key}", default: :"reports.series.#{key}"), data:, format:, **options }
    end

    def number(value) = value.to_d.round(2).to_f

    def human(model, attribute) = ->(value) { model.human_attribute_name("#{attribute}/#{value}") }

    def like(text) = "%#{ActiveRecord::Base.sanitize_sql_like(text)}%"

    # People matching a search by name, DNI or RTN.
    def people_matching(text) = Person.search(text).select(:id)
end
