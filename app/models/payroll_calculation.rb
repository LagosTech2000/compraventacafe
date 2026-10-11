# What each member earned in a pay period of a payroll, from what was
# recorded (see Payroll for the rule of each kind). A payment stores these
# numbers, so paid periods keep them if wages or prices change later.
class PayrollCalculation
  Line = Struct.new(:member, :basis, :quantity, :rate, :gross_amount, keyword_init: true)

  attr_reader :payroll, :period

  def initialize(payroll, period)
    @payroll = payroll
    @period = period
  end

  # One line per member with something earned, by name.
  def lines
    @lines ||= earned.select { |line| line.gross_amount.positive? }.sort_by { |line| line.member.sort_key }
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

    def by_day = by_rate(payroll.attendances, :day_fraction, "daily", &:daily_wage)

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
