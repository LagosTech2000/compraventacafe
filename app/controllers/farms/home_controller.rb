module Farms
  class HomeController < ApplicationController
    # What's next: pay periods that ended and are not paid.
    def index
      authorize [ :farms, :home ]
      payrolls = policy_scope(Payroll).includes(:farm, :payments)
      @active_payrolls = payrolls.active.to_a
      @to_pay = payrolls.flat_map { |payroll| payroll.periods_to_pay.map { |period| [ payroll, period, payroll.calculation(period) ] } }
                        .sort_by { |_, period, _| period.ends_on }
      @farms_count = policy_scope(Farm).active.count
    end
  end
end
