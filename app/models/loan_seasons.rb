# Loans by coffee season ("Préstamos por cosecha", Fernando, 2026-11-03): a
# loan belongs to the season of its date (Season, from September 1; a loan
# of today is of 2026-2027). For each season: what was lent, what came back
# (payments of those loans, on any date), what is owed today and how many
# are paid off or late.
class LoanSeasons
  Row = Data.define(:season, :loans_count, :people_count, :lent, :collected, :interest_collected,
                    :owed, :paid_off_count, :overdue_count) do
    def principal_collected = collected - interest_collected
    # The share of what was lent that already came back as principal.
    def recovered_percent = lent.positive? ? (principal_collected / lent * 100).round(1) : 0
  end

  attr_reader :today

  def initialize(today: Time.zone.today)
    @today = today
  end

  # The newest season first.
  def rows
    @rows ||= loans.group_by { Season.for(it.disbursed_on) }.map do |season, group|
      balances = group.reject(&:paid_off?).map { it.balance(as_of: today) }
      payments = group.flat_map(&:payments)
      Row.new(season:, loans_count: group.size, people_count: group.map(&:person_id).uniq.size,
              lent: group.sum(0.to_d, &:principal), collected: payments.sum(0.to_d, &:amount),
              interest_collected: payments.sum(0.to_d, &:interest_amount), owed: balances.sum(0.to_d, &:total_owed),
              paid_off_count: group.count(&:paid_off?), overdue_count: group.count { it.overdue?(today) })
    end.sort_by { -it.season.year }
  end

  def max_lent = rows.map(&:lent).max || 0

  private
    def loans = @loans ||= Loan.includes(:payments, :supply_items).to_a
end
