module Sales
  # Advances a buyer gives the business, paid back with coffee: registered
  # from the buyer's page in a modal, each with its printable receipt.
  class BuyerAdvancesController < ApplicationController
    before_action :set_buyer

    def new
      @advance = authorize @buyer.advances.build(received_on: Time.zone.today, payment_method: "transfer",
                                                 money_account: MoneyAccount.default_for("transfer"))
    end

    # Its receipt: original and copy, each printed on its own sheet.
    def show
      @advance = authorize @buyer.advances.find(params[:id])
    end

    def create
      @advance = authorize @buyer.advances.build(advance_params.merge(created_by: Current.user))

      if @advance.save
        receipt = sales_buyer_path(@buyer, tab: "advances", receipt: @advance.id)
        close_modal_with notice: t(".success"), fallback: receipt, visit: receipt
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      advance = authorize @buyer.advances.find(params[:id])
      advance.destroy!
      close_modal_with notice: t(".success"), fallback: sales_buyer_path(@buyer, tab: "advances")
    end

    private
      def set_buyer
        @buyer = Buyer.find(params[:buyer_id])
      end

      def advance_params
        params.expect(buyer_advance: [ :received_on, :amount, :payment_method, :money_account_id, :document_number, :observations ])
      end
  end
end
