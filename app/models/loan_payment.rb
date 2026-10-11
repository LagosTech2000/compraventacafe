# A payment ("abono") on a loan. When saved it is split into interest and
# principal (LoanBalance#split) and the split is stored. Payments go in date
# order; only the latest one can be removed, so the stored splits of the
# others stay right.
#
# A payment can also come from a coffee purchase of the same person ("pago
# con café", see PurchaseLoanSettlement): its method is "coffee" and it
# points to the purchase, whose money it takes.
#
# And from a payroll payment (farms module): method "payroll", pointing to
# the payment line of the person whose pay it takes. Those are removed with
# the payroll payment, not one by one.
class LoanPayment < ApplicationRecord
  include Auditable

  # Methods chosen by hand; "coffee" only comes from a purchase and
  # "payroll" from a payroll payment.
  PAYMENT_METHODS = %w[cash transfer check].freeze
  COFFEE = "coffee".freeze
  PAYROLL = "payroll".freeze

  belongs_to :loan
  belongs_to :created_by, class_name: "User"
  belongs_to :purchase, optional: true
  belongs_to :payroll_payment_line, optional: true

  normalizes :observations, with: FieldFormats::STRIP

  validates :paid_on, presence: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS + [ COFFEE, PAYROLL ] }
  validates :amount, numericality: { greater_than: 0, less_than: Loan::MAX_AMOUNT }
  validates :observations, length: { maximum: 500 }
  validate :in_date_order, :within_balance, :purchase_can_pay, on: :create
  validate :coffee_comes_from_purchase, :payroll_comes_from_payroll

  before_validation :split, on: :create
  after_create :settle_loan
  after_destroy :reopen_loan

  scope :chronological, -> { order(:paid_on, :id) }
  scope :newest_first, -> { order(paid_on: :desc, id: :desc) }

  def audit_label
    "#{self.class.model_name.human} #{id} · #{loan.audit_label}"
  end

  def latest?
    loan.payments.chronological.last == self
  end

  def human_payment_method
    self.class.human_attribute_name("payment_method/#{payment_method}")
  end

  def with_coffee?
    payment_method == COFFEE
  end

  def from_payroll?
    payment_method == PAYROLL
  end

  # Receipt number: the id, with 4 digits like invoices.
  def display_number
    format("%04d", id)
  end

  # What the loan owed right after this payment, on its date (later payments
  # do not count): the stored splits of this one and the ones before it.
  def balance_after
    through = loan.payments.chronological.to_a
    through = through.first(through.index(self) + 1)
    LoanBalance.new(loan, as_of: paid_on, payments: through)
  end

  private
    def balance_on_payment_date
      @balance_on_payment_date ||= LoanBalance.new(loan, as_of: paid_on)
    end

    def splittable?
      loan && paid_on && amount.to_d.positive? && !before_last_payment?
    end

    def split
      return unless splittable?

      self.interest_amount, self.principal_amount = balance_on_payment_date.split(amount)
    end

    def before_last_payment?
      last = loan.payments.chronological.last
      (last && paid_on < last.paid_on) || paid_on < loan.disbursed_on
    end

    def in_date_order
      errors.add(:paid_on, :before_last_payment) if loan && paid_on && before_last_payment?
    end

    def within_balance
      return unless splittable? && amount > balance_on_payment_date.total_owed

      owed = ActiveSupport::NumberHelper.number_to_currency(balance_on_payment_date.total_owed)
      errors.add(:amount, :over_balance, owed:)
    end

    def coffee_comes_from_purchase
      errors.add(:payment_method, :coffee_without_purchase) if with_coffee? != purchase.present?
    end

    def payroll_comes_from_payroll
      errors.add(:payment_method, :payroll_without_payment) if from_payroll? != payroll_payment_line.present?
    end

    # The purchase must be the same person's, still unpaid, and have money
    # left after the payments it already made.
    def purchase_can_pay
      return unless purchase && loan && amount

      if purchase.producer.person_id != loan.person_id
        errors.add(:purchase, :other_person)
      elsif !purchase.accepts_loan_payments?
        errors.add(:purchase, :closed)
      elsif amount > purchase.available_for_loans
        errors.add(:amount, :over_purchase, available: ActiveSupport::NumberHelper.number_to_currency(purchase.available_for_loans))
      end
    end

    def settle_loan
      loan.update!(paid_off_on: paid_on) if LoanBalance.new(loan, as_of: paid_on).settled?
    end

    def reopen_loan
      loan.update!(paid_off_on: nil) if loan.paid_off?
    end
end
