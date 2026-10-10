# Coffee season: it starts every September 1 and runs to August 31 of the
# next year. It is named after the year it starts in: season 2026 runs from
# 2026-09-01 to 2027-08-31.
class Season
  include Comparable

  START_MONTH = 9

  attr_reader :year

  def self.for(date)
    new(date.month >= START_MONTH ? date.year : date.year - 1)
  end

  def self.current
    self.for(Time.zone.today)
  end

  def initialize(year)
    @year = Integer(year)
  end

  def starts_on = Date.new(year, START_MONTH, 1)
  def ends_on = Date.new(year + 1, START_MONTH, 1) - 1
  def dates = starts_on..ends_on

  def include?(date) = dates.cover?(date)

  def <=>(other)
    year <=> other.year if other.is_a?(Season)
  end

  def eql?(other) = (self <=> other)&.zero? || false
  def hash = year.hash
end
