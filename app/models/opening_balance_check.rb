# The opening balance of each account, guided (Fernando, 2026-11-18: the
# accounts are negative because they have no opening balance): day by day
# from every source of AccountBalance, its lowest balance and the first
# day it went negative, and the least opening balance that keeps it from
# ever being negative. Only a guide: what was really there is written by
# the user (the bank statement, the cash counted).
class OpeningBalanceCheck
  Row = Data.define(:account, :first_movement_on, :lowest, :lowest_on, :negative_on, :balance) do
    def negative? = lowest.negative?
    # What the opening balance should be at least.
    def suggested_minimum = negative? ? account.opening_balance - lowest : nil
    # Movements before its opening date also count: the opening date goes before them.
    def movements_before_opening? = first_movement_on.present? && first_movement_on < account.opening_on
  end

  def initialize(accounts = MoneyAccount.active.order(:name))
    @accounts = accounts.to_a
  end

  def rows
    @rows ||= @accounts.map { |account| row(account) }
  end

  def negative = rows.select(&:negative?)

  private
    def row(account)
      days = by_day.fetch(account.id, {}).sort
      balance = account.opening_balance.to_d
      lowest = balance
      lowest_on = negative_on = nil
      days.each do |day, net|
        balance += net
        negative_on ||= day if balance.negative?
        if balance < lowest
          lowest = balance
          lowest_on = day
        end
      end
      Row.new(account:, first_movement_on: days.first&.first, lowest:, lowest_on:, negative_on:, balance:)
    end

    # { account id => { day => net } }, from every source, in SQL.
    def by_day
      @by_day ||= AccountBalance.new.sources.each_with_object(Hash.new { |hash, id| hash[id] = Hash.new(0.to_d) }) do |(relation, date, amount, account, direction), days|
        table = relation.klass.arel_table
        relation.where.not(table[account].eq(nil)).group(table[account], table[date]).sum(table[amount]).each do |(id, day), sum|
          days[id][day.to_date] += direction == :in ? sum.to_d : -sum.to_d
        end
      end
    end
end
