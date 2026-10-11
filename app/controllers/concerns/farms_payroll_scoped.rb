# For controllers of the farms module nested in a payroll: loads it.
module FarmsPayrollScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_payroll
  end

  private
    def set_payroll
      @payroll = Payroll.find(params[:payroll_id])
    end

    def payroll_tab_path(tab)
      farms_payroll_path(@payroll, tab:)
    end
end
