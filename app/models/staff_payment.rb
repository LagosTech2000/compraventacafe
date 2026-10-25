# The payment of one period of an employee of the Planilla interna, as it
# was calculated (StaffPaymentIssuer), with its printable receipt:
#
#   gross = salary + overtime hours × the role's hour rate
#           + the bonuses of the goals met + a free bonus
#   net   = gross − the advances given in the period (taken off in full)
#
# The money that leaves the account is the net (the advances already left
# when they were given). Periods are paid in order; only the latest payment
# is removed, which frees its advances and goals again.
class StaffPayment < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :member, class_name: "StaffMember", foreign_key: :staff_member_id, inverse_of: :payments
  belongs_to :role, class_name: "StaffRole", foreign_key: :staff_role_id, inverse_of: :payments
  belongs_to :money_account
  belongs_to :created_by, class_name: "User"
  has_many :advances, class_name: "StaffAdvance", dependent: :nullify, inverse_of: :payment
  has_many :goals, class_name: "StaffGoal", dependent: :nullify, inverse_of: :payment

  normalizes :extra_bonus_reason, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :period_starts_on, :period_ends_on, :paid_on, presence: true
  validates :salary, numericality: { greater_than_or_equal_to: 0, less_than: StaffRole::MAX_AMOUNT }
  validates :overtime_hours, numericality: { greater_than_or_equal_to: 0, less_than: 1_000 }
  validates :extra_bonus, numericality: { greater_than_or_equal_to: 0, less_than: StaffRole::MAX_AMOUNT }
  validates :extra_bonus_reason, presence: true, if: -> { extra_bonus.to_d.positive? }
  validates :extra_bonus_reason, length: { maximum: 200 }
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :observations, length: { maximum: 500 }
  validate :overtime_needs_rate, :net_not_negative, :money_account_active

  # Before its advances and goals are let go: its goals wait to be marked
  # again; and only the latest payment goes (prepended last, runs first).
  before_destroy :reset_goals, prepend: true
  before_destroy :ensure_latest, prepend: true

  scope :newest_first, -> { order(paid_on: :desc, id: :desc) }

  def display_number = format("%04d", id)
  def period = PayPeriod.new(period_starts_on, period_ends_on)
  def bonus_total = goals_bonus + extra_bonus

  def audit_label
    "#{display_number} · #{member&.full_name}"
  end

  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")

  def latest? = member.payments.maximum(:period_starts_on) == period_starts_on

  private
    def overtime_needs_rate
      errors.add(:overtime_hours, :without_rate) if overtime_hours.to_d.positive? && overtime_hour_rate.nil?
    end

    def net_not_negative
      errors.add(:base, :advances_over_earnings) if net_total && net_total.negative?
    end

    def money_account_active
      errors.add(:money_account, :inactive) if money_account && !money_account.active? && will_save_change_to_money_account_id?
    end

    def reset_goals
      goals.update_all(met: nil)
    end

    def ensure_latest
      return if latest?

      errors.add(:base, :not_latest)
      throw :abort
    end
end
