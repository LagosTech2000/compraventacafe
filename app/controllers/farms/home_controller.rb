module Farms
  class HomeController < ApplicationController
    # What's next: pay periods that ended and are not paid, and the payrolls
    # running or about to start.
    def index
      authorize [ :farms, :home ]
      payrolls = policy_scope(Payroll).includes(:farm, :payments)
      today = Time.zone.today
      # Each running payroll with today's period and what it amounts to so
      # far, the one paid soonest first; the ones about to start after them.
      @active_payrolls = payrolls.unfinished.newest_first.includes(:members).map do |payroll|
        period = payroll.period_containing(today) unless payroll.starts_on > today
        [ payroll, period, (payroll.calculation(period) if period && !payroll.task?) ]
      end.sort_by { |payroll, period, _| [ period ? 0 : 1, period&.ends_on || payroll.starts_on, payroll.name ] }
      @to_pay = payrolls.flat_map { |payroll| payroll.periods_to_pay.map { |period| [ payroll, period, payroll.calculation(period) ] } }
                        .sort_by { |_, period, _| period.ends_on }
      @farms_count = policy_scope(Farm).active.count
    end
  end
end
