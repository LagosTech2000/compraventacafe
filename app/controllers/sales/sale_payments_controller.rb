module Sales
  # What the buyer pays on a sale ("cobros"): registered from the sale in a
  # modal, each with its printable receipt. Only the latest one is removed.
  class SalePaymentsController < ApplicationController
    before_action :set_sale

    def new
      @payment = authorize @sale.payments.build(paid_on: Time.zone.today, amount: @sale.balance_due)
    end

    def show
      @payment = authorize @sale.payments.find(params[:id])
    end

    def create
      @payment = authorize @sale.payments.build(payment_params.merge(created_by: Current.user))

      if @payment.save
        receipt = sales_sale_path(@sale, receipt: @payment.id)
        close_modal_with notice: t(".success"), fallback: receipt, visit: receipt
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      payment = authorize @sale.payments.find(params[:id])
      payment.destroy!
      close_modal_with notice: t(".success"), fallback: sales_sale_path(@sale)
    end

    private
      def set_sale
        @sale = Sale.includes(:buyer, payments: %i[created_by money_account]).find(params[:sale_id])
      end

      def payment_params
        params.expect(sale_payment: [ :paid_on, :amount, :payment_method, :observations, :money_account_id ])
      end
  end
end
