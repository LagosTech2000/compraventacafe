# A role of the business's own payroll (Planilla interna, Fernando,
# 2026-10-24): its salary, paid in full every period (no attendance), its
# pay frequency (weekly, biweekly or monthly, the periods of PayPeriod) and
# its overtime hour rate. Changing them counts for the periods not paid yet;
# a payment keeps what it paid. Deactivated, never deleted once in use.
class StaffRole < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  MAX_AMOUNT = 10_000_000

  has_many :members, class_name: "StaffMember", dependent: :restrict_with_error, inverse_of: :role
  has_many :payments, class_name: "StaffPayment", dependent: :restrict_with_error, inverse_of: :role

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { case_sensitive: false }
  validates :salary, numericality: { greater_than: 0, less_than: MAX_AMOUNT }
  validates :pay_frequency, inclusion: { in: PayPeriod::FREQUENCIES }
  validates :overtime_hour_rate, numericality: { greater_than: 0, less_than: 100_000 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }
  scope :newest_first, -> { order(:name) }

  def audit_label = name
  def human_pay_frequency = self.class.human_pay_frequency(pay_frequency)
  def self.human_pay_frequency(frequency) = human_attribute_name("pay_frequency/#{frequency}")
  def in_use? = members.exists? || payments.exists?
end
