# What each member earned in a pay period of a payroll, from what was
# recorded (see Payroll for the rule of each kind). A payment stores these
# numbers, so paid periods keep them if wages or prices change later.
class PayrollCalculation
  # Members paid by day also carry their overtime (PayrollOvertime): extra
  # hours at the payroll's value of an extra hour and extra days at their
  # daily wage, included in gross_amount.
  Line = Struct.new(:member, :basis, :quantity, :rate, :gross_amount,
                    :overtime_hours, :overtime_hour_rate, :extra_days, :overtime_amount, keyword_init: true) do
    def overtime? = overtime_hours.to_d.positive? || extra_days.to_d.positive?
  end

  attr_reader :payroll, :period

  def initialize(payroll, period)
    @payroll = payroll
    @period = period
  end

  # One line per member with something earned, by name; a person in
  # several roles, in the order the roles were added. Extra hours without
  # the payroll's hour value stay too, so paying says what is missing.
  def lines
    @lines ||= earned.select { |line| line.gross_amount.positive? || line.overtime_hours.to_d.positive? }
                     .sort_by { |line| [ *line.member.sort_key, line.member.id ] }
  end

  def gross_total = lines.sum(0.to_d, &:gross_amount)

  private
    def earned
      case payroll.kind
      when "daily" then by_day
      # Pickers by cans; foremen by day.
      when "harvest" then by_rate(payroll.harvest_entries, :cans, "harvest") { payroll.can_price } + by_day
      when "task" then by_task
      end
    end

    # Days worked × daily wage, plus the period's overtime.
    def by_day
      days = payroll.attendances.where(worked_on: period.dates).group(:payroll_member_id).sum(:day_fraction)
      extras = payroll.overtimes.where(period_starts_on: period.starts_on).index_by(&:payroll_member_id)
      members = payroll.members.includes(:person, :role).where(id: days.keys | extras.keys).select(&:paid_by_day?)
      members.map do |member|
        quantity = days[member.id].to_d
        rate = member.daily_wage.to_d
        extra = extras[member.id]
        hours = extra&.hours.to_d
        extra_days = extra&.extra_days.to_d
        hour_rate = payroll.overtime_hour_rate if hours.positive?
        overtime_amount = (extra_days * rate + hours * hour_rate.to_d).round(2)
        Line.new(member:, basis: "daily", quantity:, rate:, gross_amount: (quantity * rate).round(2) + overtime_amount,
                 overtime_hours: hours, overtime_hour_rate: hour_rate, extra_days:, overtime_amount:)
      end
    end

    def by_rate(records, column, basis)
      quantities = records.where(worked_on: period.dates).group(:payroll_member_id).sum(column)
      members = payroll.members.includes(:person, :role).where(id: quantities.keys)
      members.map do |member|
        quantity = quantities[member.id].to_d
        rate = yield(member).to_d
        Line.new(member:, basis:, quantity:, rate:, gross_amount: (quantity * rate).round(2))
      end
    end

    # quantity: how many tasks; no single rate.
    def by_task
      tasks = payroll.tasks.where(completed_on: period.dates).includes(participants: { member: :person })
      totals = Hash.new { |hash, member| hash[member] = [ 0, 0.to_d ] }
      tasks.each do |task|
        task.shares.each do |member, share|
          totals[member][0] += 1
          totals[member][1] += share
        end
      end
      totals.map { |member, (count, amount)| Line.new(member:, basis: "task", quantity: count, rate: nil, gross_amount: amount) }
    end
end
