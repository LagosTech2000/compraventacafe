# «Cerrar el día» (Fernando, 2026-11-18: one for the whole business): from
# the day closed back, nothing is created, changed or voided (DayLock). An
# administrator closes a day after its checklist (DailyCheck); only user 1
# reopens the latest one, with a reason. Both stay in the audit.
class BusinessDayClose < ApplicationRecord
  include Auditable

  belongs_to :closed_by, class_name: "User"
  belongs_to :reopened_by, class_name: "User", optional: true

  validates :closed_on, presence: true
  validates :closed_on, not_in_future: true, on: :create
  validates :notes, :reopen_reason, length: { maximum: 500 }
  validate :after_the_last, on: :create
  validates :reopen_reason, presence: true, if: :reopened_at

  scope :active, -> { where(reopened_at: nil) }
  scope :newest_first, -> { order(closed_on: :desc, id: :desc) }

  # The last day closed (everything up to it is closed), or nil. One
  # indexed query: not cached, so a close counts at once everywhere.
  def self.locked_through = active.maximum(:closed_on)

  def self.locked?(date) = (through = locked_through) && date && date <= through

  def self.latest = active.newest_first.first

  def audit_label = I18n.l(closed_on)
  def reopened? = reopened_at.present?

  def reopen!(user:, reason:)
    self.reopen_reason = reason
    self.reopened_at = Time.current
    self.reopened_by = user
    raise ActiveRecord::RecordInvalid, self if self != self.class.latest && errors.add(:base, :not_latest)

    save!
  end

  private
    def after_the_last
      through = self.class.locked_through
      errors.add(:closed_on, :already_closed, date: I18n.l(through)) if through && closed_on && closed_on <= through
    end
end
