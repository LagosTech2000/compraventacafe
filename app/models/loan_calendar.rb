# The collection calendar ("Calendario de cobro", Fernando, 2026-11-03):
# what the unpaid loans owe today, by the week they are due. The late ones
# go apart; then this week (from today) and the next ones; the rest, later.
# Weeks run Monday to Sunday.
class LoanCalendar
  WEEKS = 12

  # key: "late", "later" or the Monday of the week (ISO).
  Bucket = Data.define(:key, :starts_on, :ends_on, :loans, :owed) do
    def count = loans.size
    def people_count = loans.map(&:person_id).uniq.size
    def week? = !%w[late later].include?(key)
  end

  attr_reader :today

  def initialize(today: Time.zone.today)
    @today = today
  end

  def loans
    @loans ||= Loan.unpaid.includes(:payments, :supply_items, person: %i[zone photo_info]).order(:due_on, :id).to_a
  end

  def balance(loan) = balances.fetch(loan.id)

  def buckets
    @buckets ||= begin
      monday = today.beginning_of_week
      weeks = Array.new(WEEKS) { |index| monday + (index * 7) }
      last_day = weeks.last + 6
      [ bucket("late", nil, today - 1) { it.due_on < today } ] +
        weeks.map { |starts| bucket(starts.iso8601, [ starts, today ].max, starts + 6) { (it.due_on >= today) && it.due_on.between?(starts, starts + 6) } } +
        [ bucket("later", last_day + 1, nil) { it.due_on > last_day } ]
    end
  end

  # The bucket asked for; without one, this week's, or the late loans when
  # this week has none.
  def selected(key)
    late, this_week = buckets.first(2)
    buckets.find { it.key == key } || (this_week.count.zero? && late.count.positive? ? late : this_week)
  end

  def total_owed = buckets.sum(0.to_d, &:owed)

  private
    def bucket(key, starts_on, ends_on, &which)
      group = loans.select(&which)
      Bucket.new(key:, starts_on:, ends_on:, loans: group, owed: group.sum(0.to_d) { balance(it).total_owed })
    end

    def balances = @balances ||= loans.to_h { [ it.id, it.balance(as_of: today) ] }
end
