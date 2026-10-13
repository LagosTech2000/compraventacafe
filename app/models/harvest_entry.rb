# Cans ("latas") of coffee a member picked on a day, in a harvest payroll.
# Foremen are paid by day, not by cans. Cans go by quarters (0.25, 0.50,
# 0.75, 1.00, 1.25…), as they are measured in the field (Fernando, 2026-10-12).
class HarvestEntry < ApplicationRecord
  include Auditable
  include PayrollWork

  CAN_STEP = BigDecimal("0.25")

  validates :cans, numericality: { greater_than: 0, less_than: 1_000 }
  validate { errors.add(:cans, :quarters) if cans && (cans % CAN_STEP).nonzero? }
  validate { errors.add(:base, :paid_by_day) if member && member.basis != "harvest" }
end
