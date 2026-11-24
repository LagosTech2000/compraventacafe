# «Cuadrar cuentas» (Fernando, 2026-11-23): every active account on one
# page, its balance at the end of the day and the amount counted; the rows
# written become cash counts (CashCount, its difference enters the balance),
# all or none. A row left empty is not counted.
class AccountSquare
  Row = Data.define(:account, :balance, :count)

  attr_reader :rows, :counted_on

  def initialize(counted_on: Time.zone.today, entries: {}, user: nil)
    @counted_on = counted_on
    balances = AccountBalance.new(as_of: counted_on)
    @rows = MoneyAccount.active.alphabetical.map do |account|
      entry = entries.fetch(account.id.to_s, {})
      count = if entry["counted_amount"].present?
        CashCount.new(money_account: account, counted_on:, counted_amount: entry["counted_amount"].to_s.delete(","),
                      observations: entry["observations"].presence, created_by: user)
      end
      Row.new(account:, balance: balances.for(account), count:)
    end
  end

  def counts = rows.filter_map(&:count)

  def save
    return false if counts.empty?

    CashCount.transaction do
      counts.each { |count| count.save || raise(ActiveRecord::Rollback) }
      true
    end || false
  end
end
