# Overtime of a member paid by day in one pay period (Fernando, 2026-10-14):
# extra hours, paid at the payroll's value of an extra hour
# (Payroll#overtime_hour_rate), and extra days, paid at the member's daily
# wage. Written at the end of the member's row in the timesheet. A paid
# period is closed.
class PayrollOvertime < ApplicationRecord
  include Auditable

  belongs_to :member, class_name: "PayrollMember", foreign_key: :payroll_member_id, inverse_of: :overtimes

  validates :period_starts_on, presence: true, uniqueness: { scope: :payroll_member_id }
  validates :hours, numericality: { greater_than_or_equal_to: 0, less_than: 1_000 }
  validates :extra_days, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  # Days go by halves, like attendance (full or half day).
  validate { errors.add(:extra_days, :halves) if extra_days && (extra_days.to_d % BigDecimal("0.5")).nonzero? }
  validate :paid_by_day, :hours_have_a_value, :period_of_payroll, :period_open
  before_destroy :ensure_period_open

  def payroll = member&.payroll
  def empty? = hours.to_d.zero? && extra_days.to_d.zero?

  def audit_label
    "#{member&.full_name} · #{period_starts_on && I18n.l(period_starts_on)}"
  end

  private
    def paid_by_day
      errors.add(:base, :not_by_day) if member && !member.paid_by_day?
    end

    def hours_have_a_value
      errors.add(:hours, :no_rate) if hours.to_d.positive? && payroll && payroll.overtime_hour_rate.blank?
    end

    def period_of_payroll
      return unless payroll && period_starts_on

      errors.add(:period_starts_on, :outside_payroll) unless payroll.period_containing(period_starts_on)&.starts_on == period_starts_on
    end

    def period_open
      errors.add(:base, :period_paid) if payroll && period_starts_on && payroll.payments.exists?(period_starts_on: period_starts_on_was || period_starts_on)
    end

    def ensure_period_open
      period_open
      throw :abort if errors.any?
    end
end
