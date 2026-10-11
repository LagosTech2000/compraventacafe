# The dates a report covers, picked from a list ("Este mes", "Temporada
# 2025"...) or typed ("custom"). A saved filter stores the key, not the
# dates, so "Este mes" is always the current month.
#
# Ranges run up to today ("to date"), and #previous is the same key one
# step back (this month to date → last month to the same day), so figures
# can be compared with the period before.
class ReportPeriod
  KEYS = %w[today yesterday this_week last_week this_month last_month last_30_days last_90_days
            this_season last_season this_year last_year all custom].freeze
  SEASON_KEY = /\Aseason_(\d{4})\z/

  attr_reader :key, :today

  def self.valid?(key) = KEYS.include?(key) || key.to_s.match?(SEASON_KEY)

  def initialize(key, from: nil, to: nil, today: Time.zone.today)
    @key = self.class.valid?(key) ? key : "all"
    @from = from
    @to = to
    @today = today
  end

  # A Date range, open at the ends when a custom date is missing; nil for
  # everything.
  def range
    @range ||= compute_range
  end

  def all? = range.nil?

  # The period just before, to compare with; nil when there is nothing to
  # compare (everything, or a custom range open at one end).
  def previous
    return if all? || range.begin.nil? || range.end.nil?

    case key
    when "custom"
      days = (range.end - range.begin).to_i + 1
      self.class.new("custom", from: range.begin - days, to: range.end - days, today:)
    when SEASON_KEY then self.class.new("season_#{Regexp.last_match(1).to_i - 1}", today:)
    else self.class.new(key, today: step_back)
    end
  end

  # Days covered, for picking the size of the chart buckets.
  def length_in_days
    return unless range&.begin && range.end

    (range.end - range.begin).to_i + 1
  end

  def season_year = key[SEASON_KEY, 1]&.to_i

  private
    def compute_range
      case key
      when "today" then today..today
      when "yesterday" then today.yesterday..today.yesterday
      when "this_week" then today.beginning_of_week..today
      when "last_week" then (today - 7).all_week
      when "this_month" then today.beginning_of_month..today
      when "last_month" then today.prev_month.all_month
      when "last_30_days" then (today - 29)..today
      when "last_90_days" then (today - 89)..today
      when "this_season" then Season.for(today).starts_on..today
      when "last_season" then Season.for(today).year.then { |year| Season.new(year - 1).dates }
      when "this_year" then today.beginning_of_year..today
      when "last_year" then today.prev_year.all_year
      when SEASON_KEY then Season.new(season_year).dates
      when "custom" then custom_range
      end
    end

    # Typed dates, in order whichever way they were typed.
    def custom_range
      return unless @from || @to

      from, to = @from && @to ? [ @from, @to ].minmax : [ @from, @to ]
      from..to
    end

    # "today" for the previous period of a key relative to today.
    def step_back
      case key
      when "today", "yesterday" then today - 1
      when "this_week", "last_week" then today - 7
      when "this_month", "last_month" then today.prev_month
      when "last_30_days" then today - 30
      when "last_90_days" then today - 90
      else today.prev_year
      end
    end
end
