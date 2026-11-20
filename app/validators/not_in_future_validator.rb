# Nothing is dated after today (Fernando, 2026-11-18: «todo debe coincidir»):
# purchases, shipments and their arrival, sales, payments, processes,
# transfers and money. A date or a time, compared by the day in
# Tegucigalpa. Only checked when the date is new or changes, so what was
# saved before never blocks another edit.
#
#   validates :paid_on, not_in_future: true
class NotInFutureValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return unless record.new_record? || record.will_save_change_to_attribute?(attribute)

    day = value.respond_to?(:in_time_zone) && !value.is_a?(Date) ? value.in_time_zone.to_date : value.to_date
    record.errors.add(attribute, :in_future) if day > Time.zone.today
  end
end
