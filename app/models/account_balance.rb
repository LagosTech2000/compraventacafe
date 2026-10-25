# The balance of each money account up to the end of a day: its opening
# balance plus what came into it minus what went out, from every module's
# payments and collections that name it, the expenses, other income and
# transfers (MoneyMovements' sources, summed in SQL). What was registered
# without an account is counted apart (#unassigned).
class AccountBalance
  Flow = Data.define(:in, :out) do
    def net = self.in - out
  end

  attr_reader :as_of

  def initialize(as_of: Time.zone.today)
    @as_of = as_of
  end

  def for(account) = account.opening_balance + flow(account.id).net

  # { account id => balance } of every account.
  def balances = @balances ||= MoneyAccount.all.to_h { |account| [ account.id, self.for(account) ] }

  def total = MoneyAccount.active.sum { |account| balances.fetch(account.id) { self.for(account) } }

  # What came in and went out of an account (nil: without an account).
  def flow(account_id)
    Flow.new(in: sums[:in].fetch(account_id, 0).to_d, out: sums[:out].fetch(account_id, 0).to_d)
  end

  def unassigned = flow(nil)

  private
    # [relation, date column, amount column, account column, direction]
    def sources
      [
        [ InvoicePayment.all, "paid_on", "amount", "money_account_id", :out ],
        [ HaulerPayment.all, "paid_on", "amount", "money_account_id", :out ],
        [ Loan.where("cash_amount > 0"), "disbursed_on", "cash_amount", "money_account_id", :out ],
        [ LoanPayment.where(payment_method: LoanPayment::PAYMENT_METHODS), "paid_on", "amount", "money_account_id", :in ],
        [ PayrollPayment.all, "paid_on", "net_total", "money_account_id", :out ],
        [ PayrollExpense.all, "spent_on", "amount", "money_account_id", :out ],
        [ SalePayment.in_money, "paid_on", "amount", "money_account_id", :in ],
        [ BuyerAdvance.all, "received_on", "amount", "money_account_id", :in ],
        [ Expense.all, "spent_on", "amount", "money_account_id", :out ],
        [ StaffPayment.all, "paid_on", "net_total", "money_account_id", :out ],
        [ StaffAdvance.all, "given_on", "amount", "money_account_id", :out ],
        [ OtherIncome.all, "received_on", "amount", "money_account_id", :in ],
        [ AccountTransfer.all, "transferred_on", "amount", "from_account_id", :out ],
        [ AccountTransfer.all, "transferred_on", "amount", "to_account_id", :in ]
      ]
    end

    def sums
      @sums ||= sources.each_with_object({ in: Hash.new(0), out: Hash.new(0) }) do |(relation, date, amount, account, direction), totals|
        table = relation.klass.arel_table
        relation.where(table[date].lteq(as_of)).group(table[account]).sum(table[amount]).each do |id, sum|
          totals[direction][id] += sum
        end
      end
    end
end
