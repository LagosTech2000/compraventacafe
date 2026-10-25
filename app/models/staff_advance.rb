# An advance given to an employee of the Planilla interna: money that
# leaves an account on its day, taken off in full from the payment of the
# period that holds that day (Fernando, 2026-10-24). It cannot fall in a
# period already paid; once taken off it stays (removing the payment frees
# it again).
class StaffAdvance < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :member, class_name: "StaffMember", foreign_key: :staff_member_id, inverse_of: :advances
  belongs_to :money_account
  belongs_to :payment, class_name: "StaffPayment", foreign_key: :staff_payment_id, optional: true, inverse_of: :advances
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :given_on, presence: true
  validates :amount, numericality: { greater_than: 0, less_than: StaffRole::MAX_AMOUNT }
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :observations, length: { maximum: 500 }
  validate :within_an_unpaid_period, if: -> { new_record? || will_save_change_to_given_on? }
  validate :money_account_active, if: :will_save_change_to_money_account_id?

  before_destroy :ensure_not_taken_off, prepend: true

  scope :newest_first, -> { order(given_on: :desc, id: :desc) }

  def display_number = format("%04d", id)
  def audit_label = "#{self.class.model_name.human} #{display_number} · #{member&.full_name}"
  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")
  def taken_off? = staff_payment_id.present?

  private
    def within_an_unpaid_period
      return unless member && given_on

      period = member.period_on(given_on)
      if period.nil?
        errors.add(:given_on, :outside_employment)
      elsif member.paid_period?(period)
        errors.add(:given_on, :in_paid_period)
      end
    end

    def money_account_active
      errors.add(:money_account, :inactive) if money_account && !money_account.active?
    end

    def ensure_not_taken_off
      return unless taken_off?

      errors.add(:base, :taken_off)
      throw :abort
    end
end
