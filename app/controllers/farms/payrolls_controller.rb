module Farms
  class PayrollsController < ApplicationController
    before_action :set_payroll, only: %i[ show edit update destroy ]

    def index
      authorize Payroll
      @filter = PayrollFilter.new(params)
      @payrolls, @next_page = @filter.results(policy_scope(Payroll))
      @count = @filter.apply(policy_scope(Payroll)).unscope(:order, :includes).count
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
        all_rows = @payroll.period_rows
        @rows, @next_page = @filter.results(all_rows)
        # Today's period stands out on top; each status shows how many it has.
        @current_row = all_rows.find { |row| row.period.include?(Time.zone.today) }
        @status_counts = PayrollPeriodFilter::STATUSES.index_with { |status| PayrollPeriodFilter.new(status:).apply(all_rows).size }
      when "members"
        @filter = PayrollMemberFilter.new(params)
        @members, @next_page = @filter.results(@payroll.members)
        @members_count = @filter.apply(@payroll.members).size
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
        # Straight to the new payroll, to add its members next.
        members = farms_payroll_path(@payroll, tab: "members")
        close_modal_with notice: t(".success"), fallback: members, visit: members
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
        params.expect(payroll: [ :farm_id, :name, :kind, :pay_frequency, :starts_on, :ends_on, :can_price, :overtime_hour_rate, :observations, :lock_version ])
      end
  end
end
