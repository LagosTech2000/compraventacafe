# The loans module's day ("Cierre diario de préstamos", Fernando,
# 2026-11-03): the loans given that day (cash and supplies) and the payments
# of that day by payment method and by account. Coffee and payroll payments
# move no money: they are counted apart from what came into an account.
class LoanDailyClose
  MethodRow = Data.define(:method, :count, :amount, :interest, :principal)
  AccountRow = Data.define(:account, :lent, :collected) do
    def net = collected - lent
  end

  attr_reader :date

  def initialize(date)
    @date = date
  end

  def loans = @loans ||= Loan.where(disbursed_on: date).includes(:money_account, :created_by, person: :photo_info, supply_items: :supply).order(:id).to_a
  def payments = @payments ||= LoanPayment.where(paid_on: date).includes(:money_account, :created_by, :purchase, { payroll_payment_line: { payment: :payroll } }, loan: :person).order(:id).to_a

  def lent = loans.sum(0.to_d, &:principal)
  def lent_cash = loans.sum(0.to_d, &:cash_amount)
  def lent_supplies = lent - lent_cash
  def collected = payments.sum(0.to_d, &:amount)
  def interest_collected = payments.sum(0.to_d, &:interest_amount)
  def principal_collected = payments.sum(0.to_d, &:principal_amount)
  # What came in as money (cash, transfer, check), not with coffee or payroll.
  def collected_money = payments.reject { it.with_coffee? || it.from_payroll? }.sum(0.to_d, &:amount)

  def by_method
    @by_method ||= payments.group_by(&:payment_method).map do |method, group|
      MethodRow.new(method:, count: group.size, amount: group.sum(0.to_d, &:amount),
                    interest: group.sum(0.to_d, &:interest_amount), principal: group.sum(0.to_d, &:principal_amount))
    end.sort_by { LoanPayment::PAYMENT_METHODS.index(it.method) || LoanPayment::PAYMENT_METHODS.size }
  end

  # Money out (cash lent) and in (money payments) by account; nil = without one.
  def by_account
    @by_account ||= begin
      out = loans.select { it.cash_amount.positive? }.group_by(&:money_account)
      came = payments.reject { it.with_coffee? || it.from_payroll? }.group_by(&:money_account)
      (out.keys | came.keys).map do |account|
        AccountRow.new(account:, lent: out.fetch(account, []).sum(0.to_d, &:cash_amount),
                       collected: came.fetch(account, []).sum(0.to_d, &:amount))
      end.sort_by { [ it.account ? 0 : 1, it.account&.name.to_s ] }
    end
  end

  def empty? = loans.empty? && payments.empty?
end
