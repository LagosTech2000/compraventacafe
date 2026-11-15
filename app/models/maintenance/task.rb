module Maintenance
  # A data maintenance task. A subclass declares:
  #   self.key  = "integrity:inventory"   (also its rake: bin/rails integrity:inventory)
  #   self.tier = :check | :fill | :decision  (reads only / fills with a clear rule / needs the client's decision)
  #   self.area = :sales | :finance | :general
  #   param :from, :date                   (its options; from the page's form or ENV in the shell)
  # and implements #sections (what it found). A task that changes data
  # (not :check) also implements #apply! (does it; returns what it changed,
  # a Hash of plain values) and .revert!(changes) (undoes it).
  # Its texts live in es.yml under maintenance.tasks.<slug>.
  class Task
    PARAM_TYPES = %i[date integer ids].freeze
    # Lines listed per section; the rest is counted.
    LINES = 200

    class << self
      attr_accessor :key, :tier, :area

      def params_spec = @params_spec ||= []
      def param(name, type, default: nil) = params_spec << { name:, type:, default: }

      def slug = key.tr(":", "_")
      def changes_data? = tier != :check
      def revertible? = changes_data?
      def title = I18n.t("maintenance.tasks.#{slug}.title")
      def text(part) = I18n.t("maintenance.tasks.#{slug}.#{part}")

      # Its options from a Hash of strings (the form) or ENV (the shell):
      # what is not valid is left out.
      def parse_params(raw)
        raw = raw.to_h.transform_keys(&:to_s)
        params_spec.each_with_object({}) do |spec, parsed|
          value = raw[spec[:name].to_s].presence || raw[spec[:name].to_s.upcase].presence
          value = cast(spec[:type], value)
          value = spec[:default] if value.nil?
          parsed[spec[:name].to_s] = value unless value.nil?
        end
      end

      def revert!(_changes) = raise(NotImplementedError)

      private
        def cast(type, value)
          return if value.nil?

          case type
          when :date then value.is_a?(Date) ? value : (Date.iso8601(value.to_s) rescue nil)
          when :integer then value.to_s.match?(/\A\d{1,4}\z/) ? value.to_i : nil
          when :ids then Array(value.is_a?(String) ? value.split(/[,\s]+/) : value).map(&:to_s).grep(/\A\d+\z/).map(&:to_i).presence
          end
        end
    end

    attr_reader :params

    def initialize(params = {})
      @params = self.class.parse_params(params)
    end

    def sections = raise(NotImplementedError)
    def apply! = raise(NotImplementedError)
    # What an apply shows: by default, what it finds afterwards.
    def sections_after_apply(_changes) = sections

    private
      def t(key, **) = I18n.t("maintenance.tasks.#{self.class.slug}.#{key}", **)
      def shared(key, **) = I18n.t("maintenance.shared.#{key}", **)
      def section(title, status, lines) = Section.new(title:, status: status.to_s, lines: capped(lines))
      def date_param(name) = params[name.to_s].then { it.is_a?(String) ? Date.iso8601(it) : it }

      def capped(lines)
        return lines if lines.size <= LINES

        lines.first(LINES) + [ shared(:more_lines, count: lines.size - LINES) ]
      end

      def pounds(value) = ActiveSupport::NumberHelper.number_to_rounded(value.to_d, precision: 2, delimiter: ",")
      def percent_text(value) = ActiveSupport::NumberHelper.number_to_rounded(value.to_d, precision: 4, strip_insignificant_zeros: true)
      def money(value) = ActiveSupport::NumberHelper.number_to_currency(value.to_d)
      def day(date) = I18n.l(date.to_date)
      def same?(a, b, tolerance = 0.01) = (a.to_d - b.to_d).abs <= tolerance
  end
end
