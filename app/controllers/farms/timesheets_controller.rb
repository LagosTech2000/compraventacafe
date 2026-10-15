module Farms
  # What each member worked in a pay period: attendance (daily payrolls) or
  # cans picked (harvest payrolls; their foremen by attendance), as grids of
  # members × days.
  class TimesheetsController < ApplicationController
    include FarmsPayrollScoped
    before_action :set_timesheet

    def show
      authorize @payroll, :show?
    end

    def update
      authorize @payroll, :record_work?

      if @timesheet.update(params.fetch(:work, {}).to_unsafe_h, params.fetch(:overtime, {}).to_unsafe_h)
        redirect_to farms_payroll_timesheet_path(@payroll, period: @timesheet.period.to_param, day: @day&.iso8601),
                    notice: t(".success")
      else
        render :show, status: :unprocessable_content
      end
    end

    private
      def set_timesheet
        raise ActiveRecord::RecordNotFound if @payroll.task?

        date = parse_date(params[:period]) || Time.zone.today
        period = @payroll.period_containing(date) || @payroll.periods.last || @payroll.period_containing(@payroll.starts_on)
        @timesheet = PayrollTimesheet.new(@payroll, period)
        # One day of the period (handy on a phone), or all of it.
        @day = parse_date(params[:day])
        @day = nil unless @day && period.include?(@day)
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end
  end
end
