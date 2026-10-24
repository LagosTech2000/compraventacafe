module Finance
  # Money moved between the business's accounts.
  class AccountTransfersController < ApplicationController
    def new
      @transfer = authorize AccountTransfer.new(transferred_on: Time.zone.today, from_account_id: params[:from])
    end

    def create
      @transfer = authorize AccountTransfer.new(transfer_params.merge(created_by: Current.user))

      if @transfer.save
        close_modal_with notice: t(".success"), fallback: finance_money_account_path(@transfer.from_account)
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      transfer = authorize AccountTransfer.find(params[:id])
      transfer.destroy!
      close_modal_with notice: t(".success"), fallback: finance_money_accounts_path
    end

    private
      def transfer_params
        params.expect(account_transfer: [ :transferred_on, :from_account_id, :to_account_id, :amount, :observations ])
      end
  end
end
