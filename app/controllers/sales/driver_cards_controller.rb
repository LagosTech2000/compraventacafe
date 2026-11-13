module Sales
  # The driver chosen in the shipment form, beside it (Fernando, 2026-11-13:
  # «que sus datos ya estén preguardados automáticamente como identidad»):
  # their identity and phone, which the remission prints, from their person.
  # Loaded into its frame each time the driver changes and again after
  # their details are edited in the modal (driver_card_controller.js).
  class DriverCardsController < ApplicationController
    def show
      authorize Shipment, :driver_card?
      @driver = StaffMember.includes(:role, person: :photo_info).find(params[:id])
    end
  end
end
