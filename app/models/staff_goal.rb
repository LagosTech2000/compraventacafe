# A goal of an employee of the Planilla interna for one period, with its
# bonus in lempiras (Fernando, 2026-10-24): when paying the period it is
# marked met (the bonus is added) or not. A goal of a paid period stays.
class StaffGoal < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :member, class_name: "StaffMember", foreign_key: :staff_member_id, inverse_of: :goals
  belongs_to :payment, class_name: "StaffPayment", foreign_key: :staff_payment_id, optional: true, inverse_of: :goals
  belongs_to :created_by, class_name: "User"

  normalizes :description, with: ->(value) { value.squish.presence }

  validates :period_starts_on, presence: true
  validates :description, presence: true, length: { maximum: 200 }
  validates :bonus_amount, numericality: { greater_than: 0, less_than: StaffRole::MAX_AMOUNT }
  validate :in_an_unpaid_period, if: -> { new_record? || will_save_change_to_period_starts_on? }

  before_destroy :ensure_not_paid, prepend: true

  def audit_label = "#{description} · #{member&.full_name}"
  def paid? = staff_payment_id.present?

  # The member's period that holds it.
  def period = member.period_on(period_starts_on)

  private
    def in_an_unpaid_period
      return unless member && period_starts_on

      period = member.period_on(period_starts_on)
      if period.nil?
        errors.add(:period_starts_on, :outside_employment)
      elsif member.paid_period?(period)
        errors.add(:period_starts_on, :in_paid_period)
      end
    end

    def ensure_not_paid
      return unless paid?

      errors.add(:base, :paid)
      throw :abort
    end
end
