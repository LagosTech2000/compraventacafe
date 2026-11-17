module Sales
  # Advances buyers and banks give the business, paid back with coffee
  # (applied to sales by a % of them) or in money (Fernando, 2026-11-16).
  # Registered from the list of advances or the buyer's page; the detail
  # shows what was applied and given back, with its printable receipt.
  class BuyerAdvancesController < ApplicationController
    before_action :set_buyer, except: :index

    def index
      authorize BuyerAdvance
      @filter = BuyerAdvanceFilter.new(params)
      scope = policy_scope(BuyerAdvance)
      @advances, @next_page = @filter.results(scope)
      @totals = totals(@filter.apply(scope))
    end

    def new
      @advance = authorize BuyerAdvance.new(buyer: @buyer, received_on: Time.zone.today, payment_method: "transfer",
                                            money_account: MoneyAccount.default_for("transfer"))
    end

    # Its detail and its receipt: original and copy, each printed on its own sheet.
    def show
      @advance = authorize @buyer.advances.includes(applications: :sale, refunds: :money_account).find(params[:id])
    end

    def create
      buyer = @buyer || Buyer.active.find_by(id: params.dig(:buyer_advance, :buyer_id))
      @advance = authorize BuyerAdvance.new(advance_params.merge(buyer:, created_by: Current.user))

      if @advance.save
        detail = sales_buyer_buyer_advance_path(buyer, @advance)
        close_modal_with notice: t(".success"), fallback: detail, visit: detail
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      advance = authorize @buyer.advances.find(params[:id])
      advance.destroy!
      close_modal_with notice: t(".success"), fallback: sales_buyer_advances_path
    end

    private
      def set_buyer
        @buyer = Buyer.find(params[:buyer_id]) if params[:buyer_id]
      end

      def advance_params
        params.expect(buyer_advance: [ :received_on, :amount, :payment_method, :money_account_id, :document_number, :observations ])
      end

      # Over every advance filtered, not only the rows loaded.
      def totals(scope)
        scope = scope.unscope(:includes, :order)
        amount, applied, refunded = scope.pick(Arel.sql("COALESCE(SUM(buyer_advances.amount), 0)"),
                                               Arel.sql("COALESCE(SUM(#{BuyerAdvance::APPLIED_SQL}), 0)"),
                                               Arel.sql("COALESCE(SUM(#{BuyerAdvance::REFUNDED_SQL}), 0)")).map(&:to_d)
        { amount:, applied:, refunded:, balance: amount - applied - refunded }
      end
  end
end
