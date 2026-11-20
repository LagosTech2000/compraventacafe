# Nothing dated on a closed day (BusinessDayClose) or before is created,
# changed or deleted (Fernando, 2026-11-18). A model names its dates with
# `locks_day :column, free: [...]`; `free` are the columns that still
# change on a closed day because of something done on an open one (the
# payment status an invoice gets from a payment of today, the buyer's
# scale of a shipment that left before, who it belongs to after merging
# people). A data-maintenance task goes over it (Current.maintenance).
module DayLock
  extend ActiveSupport::Concern

  ALWAYS_FREE = %w[updated_at lock_version].freeze

  included do
    class_attribute :day_locks, instance_writer: false, default: []
    validate :day_open
    before_destroy :day_open_to_destroy, prepend: true
  end

  class_methods do
    def locks_day(column, free: [])
      self.day_locks = day_locks + [ [ column.to_s, ALWAYS_FREE + free.map(&:to_s) ] ]
    end
  end

  def self.day(value) = value.respond_to?(:in_time_zone) && !value.is_a?(Date) ? value.in_time_zone.to_date : value

  private
    def day_open
      return if Current.maintenance
      return unless (through = BusinessDayClose.locked_through)

      day_locks.each do |column, free|
        before = DayLock.day(attribute_in_database(column)) unless new_record?
        after = DayLock.day(self[column])
        add_closed_day(after, through) if (new_record? || will_save_change_to_attribute?(column)) && after && after <= through
        add_closed_day(before, through) if before && before <= through && (changed - free).any?
      end
    end

    def day_open_to_destroy
      return if Current.maintenance
      return unless (through = BusinessDayClose.locked_through)

      closed = day_locks.filter_map { |column, _| DayLock.day(attribute_in_database(column)) }.find { it <= through }
      return unless closed

      add_closed_day(closed, through)
      throw :abort
    end

    def add_closed_day(date, through)
      message = I18n.t("activerecord.errors.messages.closed_day", date: I18n.l(through), day: I18n.l(date))
      errors.add(:base, message) unless errors.added?(:base, message)
    end
end
