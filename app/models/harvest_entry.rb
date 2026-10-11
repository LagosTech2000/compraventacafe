# Cans ("latas") of coffee a member picked on a day, in a harvest payroll.
# Foremen are paid by day, not by cans.
class HarvestEntry < ApplicationRecord
  include Auditable
  include PayrollWork

  validates :cans, numericality: { greater_than: 0, less_than: 1_000 }
  validate { errors.add(:base, :paid_by_day) if member && member.basis != "harvest" }
end
