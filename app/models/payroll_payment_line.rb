# What one member got in a payroll payment. basis says what quantity counts:
# days ("daily"), cans ("harvest") or tasks ("task"); rate is the daily
# wage or can price used. Members paid by day also keep their overtime:
# extra hours at the hour value used and extra days at the daily wage
# (overtime_amount, included in gross_amount).
class PayrollPaymentLine < ApplicationRecord
  include Auditable

  belongs_to :payment, class_name: "PayrollPayment", foreign_key: :payroll_payment_id, inverse_of: :lines
  belongs_to :member, class_name: "PayrollMember", foreign_key: :payroll_member_id
  # Loan payments taken from this pay.
  has_many :loan_payments, dependent: :restrict_with_error

  validates :basis, inclusion: { in: Payroll::KINDS }
  validates :gross_amount, numericality: { greater_than: 0 }
  validates :loans_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :loans_within_pay

  before_validation { self.net_amount = gross_amount.to_d - loans_amount.to_d }

  def overtime? = overtime_hours.to_d.positive? || extra_days.to_d.positive?

  def audit_label
    "#{member&.full_name} · #{payment&.audit_label}"
  end

  private
    def loans_within_pay
      errors.add(:loans_amount, :over_pay) if loans_amount.to_d > gross_amount.to_d
    end
end
