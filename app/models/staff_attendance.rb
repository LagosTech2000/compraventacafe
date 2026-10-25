# A day an employee of the Planilla interna worked: full (1) or half (0.5),
# marked in the payroll sheet (Fernando, 2026-10-25, from the client's
# Excel). Absent days have no row. A day of a paid period stays as it was
# paid.
class StaffAttendance < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  FRACTIONS = [ BigDecimal("1"), BigDecimal("0.5") ].freeze

  belongs_to :member, class_name: "StaffMember", foreign_key: :staff_member_id, inverse_of: :attendances

  validates :worked_on, presence: true, uniqueness: { scope: :staff_member_id }
  validates :day_fraction, inclusion: { in: FRACTIONS }
  validate :within_employment, :not_in_paid_period

  def audit_label = "#{member&.full_name} · #{I18n.l(worked_on) if worked_on}"

  private
    def within_employment
      errors.add(:worked_on, :outside_employment) if member && worked_on && !member.employed_on?(worked_on)
    end

    def not_in_paid_period
      period = member && worked_on && member.period_on(worked_on)
      errors.add(:worked_on, :in_paid_period) if period && member.paid_period?(period)
    end
end
