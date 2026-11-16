module Sales
  # The invoices of a lot (Fernando, 2026-11-13): chosen from the invoices of
  # its coffee state, in its warehouse, with a share left, with the
  # invoices' filters; each with the percent it takes. A lot made from
  # «Nueva salida» (picker=1) goes back to it once its invoices are in.
  class CoffeeBatchInvoicesController < ApplicationController
    before_action :set_batch

    def new
      authorize CoffeeBatchInvoice.new(coffee_batch: @batch), :create?
      @filter = BatchInvoiceFilter.new(params)
      # Administrators see in the same list, in grey and not to choose, the
      # invoices already whole in lots (Fernando, 2026-11-16), unless they
      # untick «Mostrar las que ya están en lotes».
      @show_taken = Current.user.admin? && params[:show_taken] != "0"
      @invoices, @next_page = @filter.results(@show_taken ? with_taken : eligible)
      @used = CoffeeBatchInvoice.used_by_invoice(@invoices.map(&:id))
      @taken_lots = @show_taken ? CoffeeBatchInvoice.where(invoice_id: @invoices.select { @used.fetch(it.id, 0).to_d >= 100 }.map(&:id)).includes(:coffee_batch).group_by(&:invoice_id) : {}
      # And finished processes (Fernando, 2026-11-16).
      @conversions = CoffeeBatchConversion.eligible_conversions(@batch).order(:finished_at, :id).to_a
      @used_conversions = CoffeeBatchConversion.used_by_conversion(@conversions.map(&:id))
    end

    def create
      authorize CoffeeBatchInvoice.new(coffee_batch: @batch), :create?
      shares = chosen(:shares)
      conversion_shares = chosen(:conversion_shares)
      return redirect_to(new_sales_coffee_batch_invoice_path(@batch, picker: params[:picker].presence), alert: t(".none")) if shares.empty? && conversion_shares.empty?

      lines = []
      CoffeeBatch.transaction do
        @batch.lock!
        shares.each do |invoice_id, share|
          line = @batch.batch_invoices.find_or_initialize_by(invoice_id: invoice_id.to_i)
          line.assign_attributes(percent: share["percent"], created_by: Current.user)
          line.save!
          lines << line
        end
        conversion_shares.each do |conversion_id, share|
          line = @batch.batch_conversions.find_or_initialize_by(coffee_conversion_id: conversion_id.to_i)
          line.assign_attributes(percent: share["percent"], created_by: Current.user)
          line.save!
          lines << line
        end
      end
      finish(t(".success", count: lines.size))
    rescue ActiveRecord::RecordInvalid => error
      record = error.record
      label = record.is_a?(CoffeeBatchConversion) ? record.coffee_conversion&.audit_label : record.invoice&.display_number
      redirect_to new_sales_coffee_batch_invoice_path(@batch, picker: params[:picker].presence),
                  alert: "#{label}: #{record.errors.full_messages.to_sentence}"
    end

    def destroy
      line = authorize @batch.batch_invoices.find_by!(invoice_id: params[:id])
      line.destroy!
      redirect_to sales_coffee_batch_path(@batch), notice: t(".success", number: line.invoice.display_number), status: :see_other
    end

    private
      # The rows marked: { id => { "chosen", "percent" } }.
      def chosen(key)
        raw = params.fetch(key, {})
        raw.keys.select { it.to_s.match?(/\A\d+\z/) }.to_h { [ it, raw.require(it).permit(:chosen, :percent).to_h ] }
           .select { |_, share| share["chosen"] == "1" }
      end

      def set_batch
        @batch = CoffeeBatch.find(params[:coffee_batch_id])
      end

      # The invoices of its coffee state with every purchase in its warehouse,
      # also the ones already whole (100 %) in lots.
      def with_taken
        Invoice.active.of_coffee_state(@batch.coffee_state)
               .where.not(id: Purchase.where.not(warehouse_id: @batch.warehouse_id).where.not(invoice_id: nil).select(:invoice_id))
               .merge(policy_scope(Invoice)).includes(:purchases, producer: :person)
      end

      def eligible
        CoffeeBatchInvoice.eligible_invoices(@batch).merge(policy_scope(Invoice)).includes(:purchases, producer: :person)
      end

      # From «Nueva salida»: the lot goes back to the shipment form.
      def finish(notice)
        @batch.reload
        if picker_request?
          close_modal_with notice:, fallback: sales_coffee_batch_path(@batch), event: "coffee_batch:created",
                           detail: { id: @batch.id, label: @batch.label, coffee_state: @batch.coffee_state, warehouse_id: @batch.warehouse_id,
                                     gross: helpers.format_pounds(@batch.gross_weight), net: helpers.format_pounds(@batch.net_weight) }
        else
          redirect_to sales_coffee_batch_path(@batch), notice:
        end
      end
  end
end
