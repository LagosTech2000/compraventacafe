# A role inside a payroll (foreman, worker...) with its daily wage. Members
# with the role earn it unless they have a wage of their own.
class PayrollRole < ApplicationRecord
  include Auditable

  belongs_to :payroll
  has_many :members, class_name: "PayrollMember", dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :payroll_id, case_sensitive: false }
  validates :daily_wage, numericality: { greater_than: 0, less_than: 100_000 }

  def audit_label
    "#{name} · #{payroll&.audit_label}"
  end
end
