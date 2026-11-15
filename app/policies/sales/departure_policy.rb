module Sales
  # «Nueva salida»: the coffee leaves to be sold, processed or moved; whoever
  # can create any of the three (a shipment, a process or a transfer)
  # chooses which, and sees only those.
  class DeparturePolicy < ApplicationPolicy
    self.module_key = "sales"

    KINDS = %w[sales.shipments sales.coffee_conversions sales.stock].freeze

    def create? = user.present? && KINDS.any? { |key| user.can?(key, :create) }
  end
end
