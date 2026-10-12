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
class ListFilter
  PER_PAGE = 50
  TYPES = %i[text date id choice].freeze

  class_attribute :fields, instance_writer: false, default: {}

  # type: :text, :date, :id, or :choice (with `in:`); `default:` applies when
  # the param is absent (not when it is blank: the user cleared it).
  def self.field(name, type, in: nil, default: nil)
    raise ArgumentError, "unknown filter type #{type}" unless TYPES.include?(type)

    self.fields = fields.merge(name => { type:, choices: binding.local_variable_get(:in), default: })
    define_method(name) { @values[name] }
  end

  attr_reader :page

  def initialize(params)
    @defaults = fields.to_h { |name, spec| [ name, parse(default_for(spec), spec) ] }
    @values = fields.to_h do |name, spec|
      [ name, params.key?(name) ? parse(params[name], spec) : @defaults[name] ]
    end
    @page = [ params[:page].to_i, 1 ].max
  end

  # Subclasses narrow the scope with the parsed values.
  def apply(scope)
    scope
  end

  # [records of this page, whether there is a next page]. The scope can be
  # a relation or an array (lists computed in Ruby, like pay periods).
  def results(scope, per_page: PER_PAGE)
    filtered = apply(scope)
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
    end.to_h
  end

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
