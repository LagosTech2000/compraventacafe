module Sales
  # An advance applied to sales by a % of it (Fernando, 2026-11-16), chosen
  # like the invoices of a lot: from the advance (its sales with something
  # due, of any buyer: a bank's advance pays any sale) or from a sale (the
  # pending advances). All of them saved together or none.
  class BuyerAdvanceSalesController < ApplicationController
    before_action -> { authorize BuyerAdvanceSale, :create? }, only: %i[new create]
    before_action :set_side, only: %i[new create]

    def new
      if @advance
        @filter = SaleFilter.new(params)
        @sales, @next_page = @filter.results(policy_scope(Sale).active.where.not(payment_status: "paid"))
      else
        @advances = policy_scope(BuyerAdvance).pending.where("#{BuyerAdvance::BALANCE_SQL} > 0")
                                              .includes(:buyer, :applications, :refunds).order(:received_on, :id).to_a
      end
    end

    def create
      chosen = params.fetch(:shares, {}).to_unsafe_h.select { |_, share| share[:chosen] == "1" }
      return redirect_back_to_side(alert: t(".none")) if chosen.empty?

      applied_on = parse_date(params[:applied_on]) || Time.zone.today
      BuyerAdvanceSale.transaction do
        chosen.each do |id, share|
          advance = @advance&.reload || policy_scope(BuyerAdvance).pending.find(id)
          sale = @sale&.reload || policy_scope(Sale).active.find(id)
          BuyerAdvanceSale.create!(buyer_advance: advance, sale:, percent: share[:percent], applied_on:, created_by: Current.user)
        end
      end
      redirect_back_to_side(notice: t(".success", count: chosen.size))
    rescue ActiveRecord::RecordInvalid => error
      redirect_back_to_side(alert: t(".failed", errors: error.record.errors.full_messages.to_sentence), again: true)
    end

    def destroy
      application = authorize BuyerAdvanceSale.find(params[:id])
      application.destroy!
      back = params[:back] == "sale" ? sales_sale_path(application.sale) : sales_buyer_buyer_advance_path(application.buyer_advance.buyer, application.buyer_advance)
      redirect_to back, notice: t(".success"), status: :see_other
    end

    private
      def set_side
        @advance = policy_scope(BuyerAdvance).find(params[:advance_id]) if params[:advance_id]
        @sale = policy_scope(Sale).find(params[:sale_id]) if params[:sale_id] && !@advance
        raise ActiveRecord::RecordNotFound unless @advance || @sale
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      def redirect_back_to_side(again: false, **flash)
        path = if again then new_sales_advance_application_path(advance_id: @advance&.id, sale_id: @sale&.id)
        elsif @advance then sales_buyer_buyer_advance_path(@advance.buyer, @advance)
        else sales_sale_path(@sale)
        end
        redirect_to path, **flash
      end
  end
end
