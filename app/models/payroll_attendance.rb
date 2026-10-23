# A day a member paid by day worked (daily payrolls, and the foremen of a
# harvest payroll): full day or half day. Absent days have no record.
class PayrollAttendance < ApplicationRecord
  include Auditable
  include PayrollWork

  FRACTIONS = [ BigDecimal("1"), BigDecimal("0.5") ].freeze

  validates :day_fraction, inclusion: { in: FRACTIONS }
  validate { errors.add(:base, :not_paid_by_day) if member && !member.paid_by_day? }
  validate :day_free_in_other_roles

  private
    # The same person in another role of the payroll: never the same day.
    def day_free_in_other_roles
      return unless member && worked_on

      other = PayrollAttendance.joins(:member).includes(member: :role)
                               .where(worked_on:, payroll_members: { payroll_id: member.payroll_id, person_id: member.person_id })
                               .where.not(payroll_member_id: member.id).first
      return unless other

      role = other.member.role
      role ? errors.add(:worked_on, :other_role, role: role.name) : errors.add(:worked_on, :other_role_own_wage)
    end
end
