# A pay period of a payroll. Decided by the owner (2026-10-10):
#
#   weekly    paid on Saturday: a period ends every Saturday
#   biweekly  paid on the 15th and the last day of the month: 1–15, 16–end
#   monthly   paid at the end of the month
#
# The first period starts on the payroll's start date and the last one ends
# on its end date (if it has one), so both can be shorter. A period never
# ends the day it starts (Fernando, 2026-10-10: "se paga el sábado lo
# trabajado durante la semana"): a payroll starting on a Saturday pays that
# day with the next Saturday. Only a payroll that ends that same day (a
# one-day task) has a one-day period.
#
# Paid periods stay as they were paid. The others follow the payroll's
# current settings, so editing its frequency or dates changes every period
# not paid yet; one that runs into a paid period stops the day before it.
class PayPeriod
  FREQUENCIES = %w[weekly biweekly monthly].freeze
  PAYDAY = 6 # Saturday (Date#wday)

  attr_reader :starts_on, :ends_on

  # The last day of the period that holds `date`, before clipping.
  def self.end_for(date, frequency)
    case frequency
    when "weekly" then date + ((PAYDAY - date.wday) % 7)
    when "biweekly" then date.day <= 15 ? date.change(day: 15) : date.end_of_month
    when "monthly" then date.end_of_month
    else raise ArgumentError, "unknown pay frequency #{frequency}"
    end
  end

  # The periods of a payroll that have started by `through`, oldest first.
  def self.for(payroll, through: Time.zone.today)
    last_day = [ payroll.ends_on, through ].compact.min
    paid = payroll.payments.reject(&:new_record?).map(&:period).sort_by(&:starts_on)
    periods = []
    start = payroll.starts_on
    while start <= last_day
      next_paid = paid.find { |period| period.ends_on >= start }
      period = next_paid&.starts_on&.<=(start) ? next_paid : unpaid_from(start, payroll, until_before: next_paid)
      periods << period
      start = period.ends_on + 1
    end
    periods
  end

  # A period not paid yet: to its payday (the next one if it starts on a
  # payday), the payroll's end, or the day before the next paid period,
  # whichever comes first.
  def self.unpaid_from(start, payroll, until_before:)
    payday = end_for(start, payroll.pay_frequency)
    payday = end_for(start + 1, payroll.pay_frequency) if payday == start
    new(start, [ payday, payroll.ends_on, until_before&.starts_on&.prev_day ].compact.min)
  end

  # The period of a payroll that holds `date` (nil outside the payroll).
  def self.containing(payroll, date)
    return if date < payroll.starts_on || (payroll.ends_on && date > payroll.ends_on)

    self.for(payroll, through: date).last
  end

  def initialize(starts_on, ends_on)
    @starts_on = starts_on
    @ends_on = ends_on
  end

  def dates = starts_on..ends_on
  def include?(date) = dates.cover?(date)
  # Its last day is payday (Saturday, the 15th, the end of the month, or the
  # day a one-day payroll ends): from then on it is due.
  def due?(today = Time.zone.today) = ends_on <= today

  def ==(other)
    other.is_a?(PayPeriod) && starts_on == other.starts_on && ends_on == other.ends_on
  end
  alias eql? ==

  def hash = [ starts_on, ends_on ].hash

  def to_param = starts_on.iso8601
end
