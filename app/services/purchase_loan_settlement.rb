# Pays loans with the money of a coffee purchase ("pago con café"): the
# producer's person owes loans, and part or all of what the purchase is
# worth goes to them instead of being paid out.
#
#   settlement = PurchaseLoanSettlement.new(purchase:, user:, paid_on:, amounts: { loan_id => amount })
#   settlement.save   # one LoanPayment per loan with an amount, all or none
#
# Each payment is a normal LoanPayment (method "coffee", pointing to the
# purchase): it covers the interest first and then the principal, and
# settles the loan when it covers everything owed on that date.
class PurchaseLoanSettlement
  include ActiveModel::Model

  attr_reader :purchase, :paid_on, :amounts, :payments, :observations

  def self.model_name = ActiveModel::Name.new(self, nil, "PurchaseLoanSettlement")

  def initialize(purchase:, user:, paid_on: nil, amounts: {}, observations: nil)
    @purchase = purchase
    @user = user
    @paid_on = parse_date(paid_on) || Time.zone.today
    @amounts = amounts.to_h.transform_keys(&:to_i).transform_values { |value| parse_amount(value) }
    @observations = observations.to_s.strip.presence
    @payments = []
  end

  def person
    purchase.producer.person
  end

  # The person's unpaid loans, the ones due first at the top.
  def open_loans
    @open_loans ||= person.loans.unpaid.includes(:payments, supply_items: :supply).order(:due_on, :id).to_a
  end

  def balance(loan)
    loan.balance(as_of: paid_on)
  end

  def total_owed
    open_loans.sum { |loan| balance(loan).total_owed }
  end

  def amount_for(loan)
    amounts[loan.id]
  end

  def total
    amounts.values.compact.sum(0.to_d)
  end

  def save
    return false unless valid_request?

    ActiveRecord::Base.transaction do
      purchase.lock!
      raise ActiveRecord::Rollback unless create_payments
    end
    errors.empty?
  end

  private
    def valid_request?
      errors.add(:base, :negative_amount) if amounts.values.compact.any?(&:negative?)
      errors.add(:base, :nothing_to_pay) if total.zero?
      errors.add(:base, :over_purchase, available: money(purchase.available_for_loans)) if total > purchase.available_for_loans
      errors.add(:base, :unknown_loan) if (amounts.keys - open_loans.map(&:id)).any?
      errors.empty?
    end

    def create_payments
      open_loans.each do |loan|
        amount = amount_for(loan)
        next unless amount&.positive?

        payment = loan.payments.create(paid_on:, amount:, payment_method: LoanPayment::COFFEE, purchase:,
                                       observations:, created_by: @user)
        payment.errors.full_messages.each do |message|
          errors.add(:base, :loan_error, loan: loan.id, detail: message)
        end
        @payments << payment
      end
      errors.empty?
    end

    def parse_amount(value)
      BigDecimal(value.to_s.delete(",").strip).round(2)
    rescue ArgumentError
      nil
    end

    def parse_date(value)
      value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def money(value)
      ActiveSupport::NumberHelper.number_to_currency(value)
    end
end
