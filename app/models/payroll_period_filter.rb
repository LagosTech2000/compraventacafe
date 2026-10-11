# Pay periods of a payroll (Payroll#period_rows, newest first): not paid
# yet (started), paid, or upcoming.
class PayrollPeriodFilter < ListFilter
  STATUSES = %w[to_pay paid upcoming].freeze

  field :status, :choice, in: STATUSES

  # rows: [Payroll::PeriodRow, ...]
  def apply(rows)
    return rows unless status

    rows.select do |row|
      case status
      when "paid" then row.paid?
      when "upcoming" then row.status == "upcoming"
      else !row.paid? && row.status != "upcoming"
      end
    end
  end
end
