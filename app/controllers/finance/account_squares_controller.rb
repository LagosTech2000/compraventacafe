module Finance
  # «Cuadrar cuentas» (Fernando, 2026-11-23): every active account counted
  # on one page (AccountSquare).
  class AccountSquaresController < ApplicationController
    include DateParam

    def new
      authorize CashCount, :create?
      @square = AccountSquare.new(counted_on: day)
    end

    def create
      authorize CashCount, :create?
      @square = AccountSquare.new(counted_on: day, entries:, user: Current.user)
      if @square.save
        redirect_to finance_money_accounts_path, notice: t(".success", count: @square.counts.size)
      else
        flash.now[:alert] = t(".nothing") if @square.counts.empty?
        render :new, status: :unprocessable_content
      end
    end

    private
      def day = [ date_param, Time.zone.today ].min

      def entries
        keys = MoneyAccount.active.ids.map(&:to_s)
        params.fetch(:entries, {}).permit(keys.to_h { [ it, %i[counted_amount observations] ] }).to_h
      end
  end
end
