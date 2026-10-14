# Pay periods of a payroll (Payroll#period_rows, newest first): not paid
# yet (started), paid, or upcoming.
class PayrollPeriodFilter < ListFilter
  STATUSES = %w[to_pay paid upcoming].freeze

  field :status, :choice, in: STATUSES

  # The periods are computed (Payroll::PeriodRow), not records: sorted in Ruby.
  STATUS_ORDER = %w[to_pay in_progress upcoming paid].freeze
  sorts period: { ruby: ->(row) { row.period.starts_on } },
        status: { ruby: ->(row) { STATUS_ORDER.index(row.status) } },
        amount: { ruby: ->(row) { row.gross_total unless row.status == "upcoming" } }

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
