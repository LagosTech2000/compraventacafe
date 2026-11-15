module Sales
  # What the loans lent of each supply and whether it was handed out
  # (Fernando, 2026-11-13): who is still owed, and «Marcar entregado» (or
  # undo it), for administrators; it cannot hand out what is not in the
  # warehouse.
  class SupplyDeliveriesController < ApplicationController
    def index
      authorize LoanSupply, :index?, policy_class: SupplyDeliveryPolicy
      @filter = SupplyDeliveryFilter.new(params)
      @lines, @next_page = @filter.results(SupplyStock.counted_lines)
    end

    def update
      line = authorize LoanSupply.find(params[:id]), policy_class: SupplyDeliveryPolicy
      line.assign_attributes(delivered_on: delivered_on, delivered_by: Current.user)
      if line.save
        redirect_back_or_to sales_supply_deliveries_path, notice: t(".success", supply: line.supply.name, person: line.loan.person.full_name)
      else
        redirect_back_or_to sales_supply_deliveries_path, alert: line.errors.full_messages.to_sentence
      end
    end

    def destroy
      line = authorize LoanSupply.find(params[:id]), policy_class: SupplyDeliveryPolicy
      line.undeliver!
      redirect_back_or_to sales_supply_deliveries_path, notice: t(".success", supply: line.supply.name)
    end

    private
      def delivered_on
        Date.iso8601(params[:delivered_on].to_s)
      rescue Date::Error
        Time.zone.today
      end
  end
end
