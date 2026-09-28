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

  # [records of this page, whether there is a next page]
  def results(scope, per_page: PER_PAGE)
    records = apply(scope).offset((page - 1) * per_page).limit(per_page + 1).to_a
    [ records.first(per_page), records.size > per_page ]
  end

  # True when the user changed something from the defaults.
  def active?
    @values.any? { |name, value| value != @defaults[name] }
  end

  def to_params
    @values.compact_blank.to_h { |name, value| [ name.to_s, value.to_s ] }
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
