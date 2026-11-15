module Sales
  # Supplies that leave the inventory without a loan (Fernando, 2026-11-14):
  # sold apart to a person (its money comes into an account) or used by the
  # business. Registered or removed, never edited.
  class SupplyExitsController < ApplicationController
    def index
      authorize SupplyExit
      @filter = SupplyExitFilter.new(params)
      @exits, @next_page = @filter.results(policy_scope(SupplyExit))
    end

    def new
      @exit = authorize SupplyExit.new(kind: "sale", exited_on: Time.zone.today, supply_id: params[:supply_id], payment_method: "cash",
                                       money_account_id: MoneyAccount.default_for("cash")&.id)
      @exit.unit_price = @exit.supply&.default_price
    end

    def create
      @exit = authorize SupplyExit.new(exit_params.merge(created_by: Current.user))

      if @exit.save
        close_modal_with notice: t(".success.#{@exit.kind}", supply: @exit.summary), fallback: sales_supply_exits_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @exit = authorize SupplyExit.includes(:supply, :person, :money_account, :created_by).find(params[:id])
    end

    def destroy
      supply_exit = authorize SupplyExit.find(params[:id])
      supply_exit.destroy!
      close_modal_with notice: t(".success"), fallback: sales_supply_exits_path
    end

    private
      def exit_params
        params.expect(supply_exit: %i[kind supply_id quantity exited_on person_id unit_price payment_method money_account_id observations])
      end
  end
end
