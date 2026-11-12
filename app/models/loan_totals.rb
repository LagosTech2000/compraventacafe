# The sums of a filtered list of loans (Préstamos, Fernando, 2026-11-12):
# what was lent, what came back and what is owed today. Only sums of each
# loan's LoanBalance; nothing is estimated.
class LoanTotals
  attr_reader :loans, :today

  def initialize(loans, today: Time.zone.today)
    @loans = loans.to_a
    @today = today
  end

  def count = loans.size
  def people_count = loans.map(&:person_id).uniq.size
  def principal = loans.sum(0.to_d) { it.principal.to_d }
  # Lent, collected and owed of principal, in cash and in supplies (Fernando, 2026-11-12).
  def cash = loans.sum(0.to_d) { it.cash_amount.to_d }
  def supplies = principal - cash
  def cash_paid = sum(:cash_paid)
  def supplies_paid = sum(:supplies_paid)
  def cash_owed = sum(:cash_owed)
  def supplies_owed = sum(:supplies_owed)
  def principal_paid = sum(:principal_paid)
  def interest_paid = sum(:interest_paid)
  def principal_owed = sum(:principal_owed)
  def interest_owed = sum(:interest_owed)
  def total_owed = principal_owed + interest_owed

  def balance(loan) = balances.fetch(loan.id)

  private
    def balances = @balances ||= loans.to_h { [ it.id, it.balance(as_of: today) ] }
    def sum(name) = loans.sum(0.to_d) { balance(it).public_send(name) }
end
