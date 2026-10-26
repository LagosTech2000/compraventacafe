module Sales
  # «Nueva salida»: the coffee leaves to be sold, processed or moved; whoever
  # can create in Comercialización chooses which.
  class DeparturePolicy < ApplicationPolicy
    self.module_key = "sales"
  end
end
