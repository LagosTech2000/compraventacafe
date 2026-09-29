# A payment ("abono") on a loan. When saved it is split into interest and
# principal (LoanBalance#split) and the split is stored. Payments go in date
# order; only the latest one can be removed, so the stored splits of the
# others stay right.
class LoanPayment < ApplicationRecord
  include Auditable

  PAYMENT_METHODS = %w[cash transfer check].freeze

  belongs_to :loan
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :paid_on, presence: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :amount, numericality: { greater_than: 0, less_than: Loan::MAX_AMOUNT }
  validates :observations, length: { maximum: 500 }
  validate :in_date_order, :within_balance, on: :create

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

    def settle_loan
      loan.update!(paid_off_on: paid_on) if LoanBalance.new(loan, as_of: paid_on).settled?
    end

    def reopen_loan
      loan.update!(paid_off_on: nil) if loan.paid_off?
    end
end
