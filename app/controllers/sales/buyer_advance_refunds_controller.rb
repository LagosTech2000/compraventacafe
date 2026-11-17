module Sales
  # Part of an advance given back in money (Fernando, 2026-11-16): out of an
  # account, never over what the advance has left. Registered or removed
  # (the latest only).
  class BuyerAdvanceRefundsController < ApplicationController
    before_action :set_advance

    def new
      @refund = authorize @advance.refunds.build(refunded_on: Time.zone.today, amount: @advance.balance, payment_method: "transfer",
                                                 money_account: MoneyAccount.default_for("transfer"))
    end

    def create
      @refund = authorize @advance.refunds.build(refund_params.merge(created_by: Current.user))

      if @refund.save
        close_modal_with notice: t(".success", amount: helpers.format_money(@refund.amount)),
                         fallback: sales_buyer_buyer_advance_path(@advance.buyer, @advance)
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      refund = authorize @advance.refunds.find(params[:id])
      refund.destroy!
      redirect_to sales_buyer_buyer_advance_path(@advance.buyer, @advance), notice: t(".success"), status: :see_other
    end

    private
      def set_advance
        @advance = policy_scope(BuyerAdvance).where(buyer_id: params[:buyer_id]).find(params[:buyer_advance_id])
      end

      def refund_params
        params.expect(buyer_advance_refund: [ :refunded_on, :amount, :payment_method, :money_account_id, :observations ])
      end
  end
end
