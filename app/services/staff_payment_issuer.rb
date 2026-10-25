# Pays one period of an employee of the Planilla interna (Fernando,
# 2026-10-24), all or nothing:
#
#   salary      the employee's own or the role's, in full (it can be
#               changed when paying)
#   overtime    hours × the role's overtime hour rate
#   goals       the bonus of each goal of the period marked met
#   free bonus  an amount with its reason
#   advances    every advance given in the period, taken off in full
#
# Periods go in order: only the oldest one not paid. The employee is locked
# meanwhile, so two payments at once cannot pay the same period.
class StaffPaymentIssuer
  Estimate = Data.define(:salary, :overtime_hours, :overtime_hour_rate, :overtime_amount, :goals, :goals_bonus,
                         :extra_bonus, :advances, :advances_total) do
    def gross_total = salary + overtime_amount + goals_bonus + extra_bonus
    def net_total = gross_total - advances_total
  end

  attr_reader :member, :period, :payment

  # met_goal_ids: the goals of the period marked met.
  def initialize(member:, period:, user: nil, salary: nil, overtime_hours: nil, met_goal_ids: [], extra_bonus: nil,
                 extra_bonus_reason: nil, paid_on: Time.zone.today, payment_method: nil, money_account_id: nil, observations: nil)
    @member = member
    @period = period
    @user = user
    @salary = salary
    @overtime_hours = overtime_hours
    @met_goal_ids = Array(met_goal_ids).compact_blank.map(&:to_i)
    @extra_bonus = extra_bonus
    @extra_bonus_reason = extra_bonus_reason
    @paid_on = paid_on
    @payment_method = payment_method
    @money_account_id = money_account_id
    @observations = observations
  end

  def goals = member.goals.select { period.include?(it.period_starts_on) && !it.paid? }
  def advances = member.pending_advances.select { period.include?(it.given_on) }

  # What it pays with what was given (all goals met when none was marked:
  # the preview of a period before paying it counts none).
  def estimate
    role = member.role
    salary = number(@salary, member.salary)
    hours = number(@overtime_hours, 0)
    rate = role.overtime_hour_rate
    met = goals.select { @met_goal_ids.include?(it.id) }
    Estimate.new(salary:, overtime_hours: hours, overtime_hour_rate: rate, overtime_amount: (rate ? (hours * rate).round(2) : 0.to_d),
                 goals:, goals_bonus: met.sum(0.to_d, &:bonus_amount), extra_bonus: number(@extra_bonus, 0),
                 advances:, advances_total: advances.sum(0.to_d, &:amount))
  end

  def call
    StaffMember.transaction do
      member.lock!
      member.payments.reset
      unless member.period_to_pay == period
        refuse(:not_next_period)
        raise ActiveRecord::Rollback
      end

      result = estimate
      @payment = member.payments.build(role: member.role, period_starts_on: period.starts_on, period_ends_on: period.ends_on,
                                       salary: result.salary, overtime_hours: result.overtime_hours,
                                       overtime_hour_rate: (result.overtime_hour_rate if result.overtime_hours.positive?),
                                       overtime_amount: result.overtime_amount, goals_bonus: result.goals_bonus,
                                       extra_bonus: result.extra_bonus, extra_bonus_reason: @extra_bonus_reason,
                                       gross_total: result.gross_total, advances_total: result.advances_total, net_total: result.net_total,
                                       paid_on: @paid_on, payment_method: @payment_method, money_account_id: @money_account_id,
                                       observations: @observations, created_by: @user)
      raise ActiveRecord::Rollback unless @payment.save

      result.goals.each { |goal| goal.update!(met: @met_goal_ids.include?(goal.id), payment: @payment) }
      result.advances.each { |advance| advance.update!(payment: @payment) }
      true
    end || false
  end

  private
    def number(value, default)
      value.to_s.strip.empty? ? default.to_d : BigDecimal(value.to_s)
    rescue ArgumentError
      default.to_d
    end

    def refuse(error)
      @payment = StaffPayment.new(member:, period_starts_on: period.starts_on, period_ends_on: period.ends_on)
      @payment.errors.add(:base, error)
    end
end
