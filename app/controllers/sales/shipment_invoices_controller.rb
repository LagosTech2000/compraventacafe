module Sales
  # The purchase invoices of a shipment's coffee (Fernando, 2026-11-12), for
  # its cost: chosen from the invoices of its coffee state that are on no
  # shipment, with the invoices' filters, marked and linked at once. Each
  # one is let go apart.
  class ShipmentInvoicesController < ApplicationController
    before_action :set_shipment

    def new
      authorize ShipmentInvoice.new(shipment: @shipment), :create?
      @filter = InvoiceFilter.new(params)
      @invoices, @next_page = @filter.results(eligible)
    end

    def create
      authorize ShipmentInvoice.new(shipment: @shipment), :create?
      invoices = eligible.where(id: Array(params[:invoice_ids])).to_a
      return redirect_to(new_sales_shipment_invoice_path(@shipment), alert: t(".none")) if invoices.empty?

      ShipmentInvoice.transaction do
        invoices.each { |invoice| @shipment.shipment_invoices.create!(invoice:, created_by: Current.user) }
      end
      redirect_to sales_shipment_path(@shipment, anchor: "shipment-cost"), notice: t(".success", count: invoices.size)
    end

    def destroy
      link = authorize @shipment.shipment_invoices.find_by!(invoice_id: params[:id])
      link.destroy!
      redirect_to sales_shipment_path(@shipment, anchor: "shipment-cost"), notice: t(".success", number: link.invoice.display_number),
                  status: :see_other
    end

    private
      def set_shipment
        @shipment = Shipment.find(params[:shipment_id])
      end

      # Of its coffee state, on no shipment.
      def eligible
        policy_scope(Invoice).of_coffee_state(@shipment.coffee_state).without_shipment
                             .includes(:purchases, producer: :person)
      end
  end
end
