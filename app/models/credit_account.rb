# A person's account with the business ("estado de cuenta"): every loan
# with what it owes today, the totals, the full history of loans and
# payments, and the payer score.
class CreditAccount
  Movement = Struct.new(:date, :kind, :loan, :amount, :interest, :principal, :record, keyword_init: true)

  attr_reader :person, :loans

  def initialize(person, today: Time.zone.today)
    @person = person
    @today = today
    # Loaded once per list (preloaded loans, payments and supplies) or here.
    # Only the user's own when they see only theirs (OwnedRecord).
    owner = Current.owner if OwnedRecord.restricted?(Current.owner)
    @loans = if person.association(:loans).loaded?
      person.loans.select { owner.nil? || it.created_by_id == owner.id }.sort_by { |loan| [ loan.disbursed_on, loan.id ] }.reverse
    else
      person.loans.owned.includes(:payments, :supply_items).newest_first.to_a
    end
  end

  def balance(loan)
    balances[loan.id]
  end

  def score
    @score ||= PayerScore.new(loans, today: @today)
  end

  def lent = loans.sum(&:principal)
  # Principal lent, paid and owed in cash and in supplies (Fernando, 2026-11-12).
  def lent_cash = loans.sum { it.cash_amount.to_d }
  def lent_supplies = lent - lent_cash
  def cash_paid = balances.values.sum(&:cash_paid)
  def supplies_paid = principal_paid - cash_paid
  def cash_owed = balances.values.sum(&:cash_owed)
  def supplies_owed = principal_owed - cash_owed
  def principal_paid = balances.values.sum(&:principal_paid)
  def interest_paid = balances.values.sum(&:interest_paid)
  def principal_owed = balances.values.sum(&:principal_owed)
  def interest_owed = balances.values.sum(&:interest_owed)
  def total_owed = principal_owed + interest_owed
  def overdue_loans = loans.select { |loan| loan.overdue?(@today) }
  def open_loans = loans.reject(&:paid_off?)

  # Every loan given and every payment, most recent first.
  def movements
    entries = loans.flat_map do |loan|
      [ Movement.new(date: loan.disbursed_on, kind: :loan, loan:, amount: loan.principal, record: loan) ] +
        loan.payments.map do |payment|
          Movement.new(date: payment.paid_on, kind: :payment, loan:, amount: payment.amount,
                       interest: payment.interest_amount, principal: payment.principal_amount, record: payment)
        end
    end
    entries.sort_by { |entry| [ entry.date, entry.kind == :payment ? 1 : 0, entry.record.id ] }.reverse
  end

  private
    def balances
      @balances ||= loans.to_h do |loan|
        [ loan.id, loan.balance(as_of: @today) ]
      end
    end
end
