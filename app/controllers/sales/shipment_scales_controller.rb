module Sales
  # Removes one scale of a shipment (Fernando, 2026-11-15): the local one
  # (an administrator; like «Sin báscula local», it takes nothing from the
  # stock until completed; a sold shipment's sale follows), or the buyer's
  # (back to «en camino»; not while in a sale). Audited.
  class ShipmentScalesController < ApplicationController
    def destroy
      shipment = Shipment.find(params[:shipment_id])
      if params[:side] == "origin"
        authorize shipment, :remove_origin?
        shipment.assign_attributes(skip_origin: "1", origin_skippable: true, weights_by_admin: true)
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
