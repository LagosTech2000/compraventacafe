module Sales
  # An entry of the supplies' inventory (Fernando, 2026-11-12): saved, it
  # registers its investment in Control financiero; removed, it takes it away.
  class SupplyEntriesController < ApplicationController
    def new
      @entry = authorize SupplyEntry.new(supply_id: params[:supply_id], received_on: Time.zone.today, payment_method: "cash",
                                         money_account_id: MoneyAccount.default_for("cash")&.id)
    end

    def create
      @entry = authorize SupplyEntry.new(entry_params.merge(created_by: Current.user))

      if @entry.save
        close_modal_with notice: t(".success", supply: @entry.supply.name), fallback: sales_supply_stock_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @entry = authorize SupplyEntry.includes(:supply, :created_by, expense: %i[money_account category]).find(params[:id])
    end

    def destroy
      entry = authorize SupplyEntry.find(params[:id])
      if entry.destroy
        close_modal_with notice: t(".success"), fallback: sales_supply_stock_path
      else
        redirect_to sales_supply_stock_path, alert: entry.errors.full_messages.to_sentence
      end
    end

    private
      def entry_params
        params.expect(supply_entry: [ :supply_id, :quantity, :amount, :received_on, :payee, :receipt_number, :observations,
                                      :finance_category_id, :money_account_id, :payment_method ])
      end
  end
end
