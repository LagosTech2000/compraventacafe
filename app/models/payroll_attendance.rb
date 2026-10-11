# A day a member paid by day worked (daily payrolls, and the foremen of a
# harvest payroll): full day or half day. Absent days have no record.
class PayrollAttendance < ApplicationRecord
  include Auditable
  include PayrollWork

  FRACTIONS = [ BigDecimal("1"), BigDecimal("0.5") ].freeze

  validates :day_fraction, inclusion: { in: FRACTIONS }
  validate { errors.add(:base, :not_paid_by_day) if member && !member.paid_by_day? }
end
