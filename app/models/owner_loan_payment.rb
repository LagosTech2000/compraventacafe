# A payment of an owners' loan (OwnerLoan): it pays the interest owed first
# and the rest lowers the principal, never more than is owed that day, in
# date order; only the last one is removed. With an account, it went out of
# it (MoneyMovements «owner_loan_payments»).
class OwnerLoanPayment < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  include HasMoneyAccount
  live_updates :finance

  PAYMENT_METHODS = Invoice::PAYMENT_METHODS

  belongs_to :owner_loan, inverse_of: :payments
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :paid_on, presence: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :amount, numericality: { greater_than: 0, less_than: OwnerLoan::MAX_AMOUNT }
  validates :observations, length: { maximum: 500 }
  validate :in_date_order, :within_balance, on: :create

  before_validation :split, on: :create
  after_create :settle_loan
  after_destroy { owner_loan.update!(paid_off_on: nil) if owner_loan.paid? }

  scope :chronological, -> { order(:paid_on, :id) }

  def audit_label = "#{self.class.model_name.human} · #{owner_loan&.audit_label}"
  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")
  def latest? = owner_loan.payments.reload.last == self

  private
    def balance_on_date = @balance_on_date ||= LoanBalance.new(owner_loan, as_of: paid_on, payments: owner_loan.payments.reject(&:new_record?))

    def splittable? = owner_loan && paid_on && amount.to_d.positive? && !out_of_order?

    def out_of_order?
      last = owner_loan.payments.reject(&:new_record?).last
      (last && paid_on < last.paid_on) || paid_on < owner_loan.disbursed_on
    end

    def split
      return unless splittable?

      self.interest_amount, self.principal_amount = balance_on_date.split(amount)
    end

    def in_date_order
      errors.add(:paid_on, :before_last_payment) if owner_loan && paid_on && out_of_order?
    end

    def within_balance
      return unless splittable? && amount > balance_on_date.total_owed

      errors.add(:amount, :over_balance, owed: ActiveSupport::NumberHelper.number_to_currency(balance_on_date.total_owed))
    end

    def settle_loan
      owner_loan.update!(paid_off_on: paid_on) if LoanBalance.new(owner_loan, as_of: paid_on, payments: owner_loan.payments.reload.to_a).settled?
    end
end
