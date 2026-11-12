module Sales
  # The remission of a shipment (Fernando, 2026-11-12): the paper that goes
  # with the coffee, as the client's booklet. Original and copy, each on its
  # own sheet. Who sees the shipment prints it; nothing is saved.
  class RemissionsController < ApplicationController
    def show
      @shipment = authorize Shipment.includes(:buyer, :vehicle, vehicle: :vehicle_type, driver: :person)
                                    .find(params[:shipment_id]), :show?
      @buyer = Buyer.includes(:department, :municipality).find(@shipment.buyer_id)
    end
  end
end
