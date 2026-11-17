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
      @exit = authorize SupplyExit.new(kind: "sale", exited_on: Time.zone.today, payment_method: "cash",
                                       money_account_id: MoneyAccount.default_for("cash")&.id)
      supply = Supply.active.find_by(id: params[:supply_id])
      @exit.lines.build(supply:, unit_price: supply&.default_price)
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
      @exit = authorize SupplyExit.includes({ lines: :supply }, :person, :money_account, :created_by).find(params[:id])
    end

    def destroy
      supply_exit = authorize SupplyExit.find(params[:id])
      supply_exit.destroy!
      close_modal_with notice: t(".success"), fallback: sales_supply_exits_path
    end

    private
      def exit_params
        params.expect(supply_exit: [ :kind, :exited_on, :person_id, :payment_method, :money_account_id, :observations,
                                     { lines_attributes: [ %i[supply_id quantity unit_price _destroy] ] } ])
      end
  end
end
