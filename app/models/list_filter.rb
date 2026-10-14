# Base for every list's filters. A subclass declares its fields and how they
# narrow a relation; this class parses params safely (garbage is ignored),
# pages the result and rebuilds the query string for links.
#
#   class ZoneFilter < ListFilter
#     field :q, :text
#     def apply(scope) = q ? scope.where("name ILIKE ?", like(q)) : scope
#   end
#
#   records, next_page = ZoneFilter.new(params).results(Zone.all)
#
# Every column of a list sorts (Fernando, 2026-10-13): a subclass declares
# how with `sorts`, and ?sort=key&dir=asc|desc orders the whole filtered
# list (every page), not just the rows on screen. Without a sort the list
# keeps its own order (newest first).
#
#   sorts name: text("zones.name"),                                    # text, in Spanish order
#         zone: { sql: text("zones.name"), joins: { person: :zone } },  # SQL that needs a join
#         total: "purchases.total",                                     # any SQL
#         owed: { ruby: ->(loan) { loan.balance.total_owed } }          # computed: sorted in Ruby
#
# SQL can be a list (several columns) or a lambda that returns it. Text
# columns go through `text`: Spanish order without minding case or accents
# ("Álvaro" before "Beto"). A Ruby sort loads every filtered record: for
# computed values of lists that stay small. Empty values go last either way.
class ListFilter
  PER_PAGE = 50
  TYPES = %i[text date id choice].freeze
  DIRECTIONS = %w[asc desc].freeze

  class_attribute :fields, instance_writer: false, default: {}
  class_attribute :sortings, instance_writer: false, default: {}

  # Spanish order where PostgreSQL has ICU (es-x-icu); else, case only.
  TextColumn = Data.define(:sql) do
    def to_s = ListFilter.spanish_collation? ? %(#{sql} COLLATE "es-x-icu") : "LOWER(#{sql})"
  end

  def self.text(*columns) = columns.map { TextColumn.new(it) }

  def self.spanish_collation?
    return @spanish_collation if defined?(@spanish_collation)

    @spanish_collation = ActiveRecord::Base.connection.select_value("SELECT 1 FROM pg_collation WHERE collname = 'es-x-icu'").present?
  end

  def self.sorts(**specs)
    self.sortings = sortings.merge(specs.transform_keys(&:to_s).transform_values { |spec| spec.is_a?(Hash) ? spec : { sql: spec } })
  end

  # type: :text, :date, :id, or :choice (with `in:`); `default:` applies when
  # the param is absent (not when it is blank: the user cleared it).
  def self.field(name, type, in: nil, default: nil)
    raise ArgumentError, "unknown filter type #{type}" unless TYPES.include?(type)

    self.fields = fields.merge(name => { type:, choices: binding.local_variable_get(:in), default: })
    define_method(name) { @values[name] }
  end

  attr_reader :page, :sort, :dir

  def initialize(params)
    @defaults = fields.to_h { |name, spec| [ name, parse(default_for(spec), spec) ] }
    @values = fields.to_h do |name, spec|
      [ name, params.key?(name) ? parse(params[name], spec) : @defaults[name] ]
    end
    @page = [ params[:page].to_i, 1 ].max
    @sort = params[:sort].to_s.presence_in(sortings.keys)
    @dir = @sort && (params[:dir].to_s.presence_in(DIRECTIONS) || "asc")
  end

  def sortable?(key) = sortings.key?(key.to_s)

  # Subclasses narrow the scope with the parsed values.
  def apply(scope)
    scope
  end

  # [records of this page, whether there is a next page]. The scope can be
  # a relation or an array (lists computed in Ruby, like pay periods).
  def results(scope, per_page: PER_PAGE)
    filtered = sorted(apply(scope))
    skip = (page - 1) * per_page
    records = filtered.is_a?(Array) ? filtered.drop(skip).first(per_page + 1) : filtered.offset(skip).limit(per_page + 1).to_a
    [ records.first(per_page), records.size > per_page ]
  end

  # True when the user changed something from the defaults.
  def active?
    active_fields.any?
  end

  # The fields the user changed from their defaults, in declaration order.
  def active_fields
    @values.keys.reject { |name| @values[name] == @defaults[name] }
  end

  # The query string. A field cleared on purpose (its default is not blank,
  # like the purchases' dates that start on today) is kept as "", so links
  # (next page, sorting) do not bring the default back.
  def to_params
    @values.filter_map do |name, value|
      if value.present? then [ name.to_s, value.to_s ]
      elsif @defaults[name].present? then [ name.to_s, "" ]
      end
    end.to_h.merge(sort_params)
  end

  # The query string's sort, when there is one.
  def sort_params = sort ? { "sort" => sort, "dir" => dir } : {}

  # The query string with these fields back to their defaults (an active
  # filter's ×).
  def params_without(*names)
    to_params.except(*names.map(&:to_s))
  end

  # Each field's default as the form shows it ("" for none), to put a field
  # back (live_filter_controller.js).
  def default_values(*names)
    names = fields.keys if names.empty?
    names.to_h { |name| [ name.to_s, @defaults[name].to_s ] }
  end

  private
    def sorted(scope)
      spec = sort && sortings[sort]
      return scope unless spec

      spec[:ruby] || scope.is_a?(Array) ? sorted_in_ruby(scope.to_a, spec.fetch(:ruby)) : sorted_in_sql(scope, spec)
    end

    def sorted_in_sql(scope, spec)
      scope = scope.left_joins(spec[:joins]) if spec[:joins]
      columns = Array(spec[:sql].respond_to?(:call) ? spec[:sql].call : spec[:sql]).map(&:to_s)
      order = columns.map { |column| "#{column} #{dir.upcase} NULLS LAST" } << "#{scope.quoted_table_name}.id #{dir.upcase}"
      scope.reorder(Arel.sql(order.join(", ")))
    end

    # Stable: equal values keep the list's own order. Text sorts without
    # minding case or accents ("Álvarez" next to "Alvarez").
    def sorted_in_ruby(records, value)
      keyed = records.each_with_index.map { |record, index| [ sort_value(value.call(record)), index, record ] }
      present, missing = keyed.partition { |key, _, _| !key.nil? }
      present.sort! { |a, b| ((dir == "desc" ? b[0] <=> a[0] : a[0] <=> b[0]) || 0).nonzero? || a[1] <=> b[1] }
      (present + missing).map(&:last)
    end

    def sort_value(value)
      case value
      when String then value.blank? ? nil : I18n.transliterate(value).downcase
      when Array then value.map { |part| sort_value(part) || "" }
      else value
      end
    end

    def default_for(spec)
      spec[:default].respond_to?(:call) ? spec[:default].call : spec[:default]
    end

    def parse(raw, spec)
      value = raw.is_a?(Date) ? raw : raw.to_s.strip
      case spec[:type]
      when :text then value.first(100).presence
      when :id then value.to_s.match?(/\A\d+\z/) ? value.to_i : nil
      when :choice then value.presence_in(spec[:choices])
      when :date then value.is_a?(Date) ? value : parse_date(value)
      end
    end

    def parse_date(value)
      Date.iso8601(value)
    rescue Date::Error
      nil
    end

    def like(text)
      "%#{ActiveRecord::Base.sanitize_sql_like(text)}%"
    end
end
