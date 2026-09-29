# How reliably a person pays back loans, as the owner chose (2026-09-28):
#
#   score = loans paid in full by their due date
#           ÷ loans already paid off or past their due date × 100
#
# A loan past its due date with money still owed counts as not on time.
# Loans not yet due and unpaid do not count. With none to count there is no
# score ("Sin historial").
class PayerScore
  # Lowest score of each category, best first.
  CATEGORIES = { excellent: 85, good: 70, fair: 50, risk: 0 }.freeze

  attr_reader :value, :evaluated_count, :on_time_count

  def initialize(loans, today: Time.zone.today)
    evaluated = loans.select { |loan| loan.paid_off? || loan.overdue?(today) }
    @evaluated_count = evaluated.size
    @on_time_count = evaluated.count(&:paid_on_time?)
    @value = (on_time_count * 100.0 / evaluated_count).round if evaluated_count.positive?
  end

  def category
    return :no_history if value.nil?

    CATEGORIES.find { |_, minimum| value >= minimum }.first
  end
end
