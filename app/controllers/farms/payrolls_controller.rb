module Farms
  class PayrollsController < ApplicationController
    before_action :set_payroll, only: %i[ show edit update destroy ]

    def index
      authorize Payroll
      @filter = PayrollFilter.new(params)
      @payrolls, @next_page = @filter.results(policy_scope(Payroll))
    end

    TABS = %w[periods members tasks expenses].freeze

    # Pinned accounts on top, then one tab: pay periods, members (and roles),
    # tasks (payrolls by task) or expenses.
    def show
      @tabs = @payroll.task? ? TABS : TABS - %w[tasks]
      @tab = params[:tab].presence_in(@tabs) || @tabs.first

      case @tab
      when "periods"
        @filter = PayrollPeriodFilter.new(params)
        @rows, @next_page = @filter.results(@payroll.period_rows)
      when "members"
        @filter = PayrollMemberFilter.new(params)
        @members, @next_page = @filter.results(@payroll.members)
      when "tasks"
        @filter = PayrollTaskFilter.new(params)
        @tasks, @next_page = @filter.results(@payroll.tasks)
      when "expenses"
        @filter = PayrollExpenseFilter.new(params)
        filtered = @filter.apply(@payroll.expenses)
        @filtered_total = filtered.sum(:amount)
        @expenses, @next_page = @filter.results(@payroll.expenses)
      end
    end

    def new
      farm = Farm.active.find_by(id: params[:farm_id])
      @payroll = authorize Payroll.new(farm:, kind: "daily", pay_frequency: "weekly", starts_on: Time.zone.today)
    end

    def create
      @payroll = authorize Payroll.new(payroll_params.merge(created_by: Current.user))

      if @payroll.save
        close_modal_with notice: t(".success"), fallback: farms_payroll_path(@payroll, tab: "members")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @payroll.update(payroll_params)
        close_modal_with notice: t(".success"), fallback: farms_payroll_path(@payroll)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @payroll.destroy
        close_modal_with notice: t(".success"), fallback: farms_payrolls_path
      else
        redirect_back_or_to farms_payroll_path(@payroll), alert: t(".in_use")
      end
    end

    private
      def set_payroll
        @payroll = authorize Payroll.find(params[:id])
      end

      def payroll_params
        params.expect(payroll: [ :farm_id, :name, :kind, :pay_frequency, :starts_on, :ends_on, :can_price, :observations ])
      end
  end
end
