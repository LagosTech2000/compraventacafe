module Sales
  # Takes a process's share out of a lot (Fernando, 2026-11-16); it is
  # added from the lot's «Agregar facturas» (CoffeeBatchInvoicesController).
  class CoffeeBatchConversionsController < ApplicationController
    def destroy
      batch = CoffeeBatch.find(params[:coffee_batch_id])
      line = authorize batch.batch_conversions.find_by!(coffee_conversion_id: params[:id])
      line.destroy!
      redirect_to sales_coffee_batch_path(batch), notice: t(".success", conversion: line.coffee_conversion.audit_label), status: :see_other
    end
  end
end
