module Sales
  # The shipment weighed on the buyer's scale: its gross weight, sacks,
  # humidity and damage (or yield), the weight note and the day. The net
  # uses the purchase calculation; the difference with the local scale
  # shows at once.
  class ArrivalsController < ApplicationController
    before_action :set_shipment

    def edit
      @shipment.received_on ||= Time.zone.today
      @shipment.destination_sacks ||= @shipment.origin_sacks
      %w[humidity_percent damage_percent yield_factor].each do |input|
        @shipment["destination_#{input}"] ||= @shipment["origin_#{input}"]
      end
    end

    def update
      @shipment.assign_attributes(arrival_params)
      @shipment.receiving = true
      @shipment.asking_reasons = true

      if settling?
        if (sale = save_and_sell)
          close_modal_with notice: t(".settled", number: @shipment.display_number, sale: sale.display_number), fallback: sales_sale_path(sale)
        else
          render :edit, status: :unprocessable_content
        end
      elsif @shipment.save
        close_modal_with notice: t(".success", number: @shipment.display_number), fallback: sales_shipment_path(@shipment)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      # «Liquidar salida» (Fernando, 2026-11-18: every sale has one
      # shipment): the buyer's scale, the sale on that weight and its
      # collection, saved together or none (SaleIssuer's rules). Sold and
      # collected the day it was weighed.
      def settling? = params[:settle_now].present? && policy(Sale).create?

      def save_and_sell
        settle = params.fetch(:settle, {}).permit(:price_unit, :unit_price, :quintal_pounds, :buyer_document_number, :payment_status, :payment_method, :amount, :money_account_id)
        Shipment.transaction do
          raise ActiveRecord::Rollback unless @shipment.save

          result = SaleIssuer.new(buyer: @shipment.buyer, shipment_ids: [ @shipment.id ], user: Current.user,
                                  sale: { sold_on: @shipment.received_on, **settle.slice(:price_unit, :unit_price, :quintal_pounds, :buyer_document_number).to_h.symbolize_keys },
                                  payment_status: settle[:payment_status], payment_method: settle[:payment_method], paid_on: @shipment.received_on,
                                  amount: settle[:amount], money_account_id: settle[:money_account_id]).call
          next result.sale if result.success?

          result.sale.errors.full_messages.each { @shipment.errors.add(:base, it) }
          raise ActiveRecord::Rollback
        end
      end

      def set_shipment
        @shipment = Shipment.includes(:buyer, :active_sale_line, :sale).find(params[:shipment_id])
        authorize @shipment, :receive?
      end

      def arrival_params
        params.expect(shipment: [ :received_on, :weight_note_number, :destination_gross_weight, :destination_sacks,
                                  :destination_humidity_percent, :destination_damage_percent, :destination_yield_factor, :difference_reason, :lock_version ])
      end
  end
end
