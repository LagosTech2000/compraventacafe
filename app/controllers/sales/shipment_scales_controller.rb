module Sales
  # Removes one scale of a shipment (Fernando, 2026-11-15): the local one
  # (an administrator, while on its way; like «Sin báscula local», it takes
  # nothing from the stock until completed), or the buyer's (back to «en
  # camino»; not while in a sale): how a weighed shipment is corrected.
  # Audited.
  class ShipmentScalesController < ApplicationController
    def destroy
      shipment = Shipment.find(params[:shipment_id])
      if params[:side] == "origin"
        authorize shipment, :remove_origin?
        shipment.assign_attributes(skip_origin: "1", origin_skippable: true)
        shipment.save!
      else
        authorize shipment, :remove_destination?
        shipment.remove_destination!
      end
      redirect_to sales_shipment_path(shipment), notice: t(".success.#{params[:side]}")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to sales_shipment_path(shipment), alert: error.record.errors.full_messages.to_sentence
    end
  end
end
