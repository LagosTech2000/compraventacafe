module Sales
  # An entry of the supplies' inventory (Fernando, 2026-11-12): saved, it
  # registers its investment in Control financiero; removed, it takes it
  # away. One invoice of the supplier, with its supplies (Fernando, 2026-11-13).
  class SupplyEntriesController < ApplicationController
    def new
      @entry = authorize SupplyEntry.new(received_on: Time.zone.today, payment_method: "cash",
                                         money_account_id: MoneyAccount.default_for("cash")&.id)
      @entry.lines.build(supply_id: params[:supply_id])
    end

    def create
      @entry = authorize SupplyEntry.new(entry_params.merge(created_by: Current.user))

      if @entry.save
        close_modal_with notice: t(".success", supplies: @entry.lines.map { it.supply.name }.to_sentence), fallback: sales_supply_stock_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @entry = authorize SupplyEntry.includes(:created_by, lines: :supply, expense: %i[money_account receipt_info category]).find(params[:id])
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
        params.expect(supply_entry: [ :received_on, :payee, :receipt_number, :observations, :receipt_upload,
                                      :finance_category_id, :money_account_id, :payment_method,
                                      lines_attributes: [ [ :supply_id, :quantity, :amount, :_destroy ] ] ])
      end
  end
end
