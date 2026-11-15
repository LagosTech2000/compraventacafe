module Sales
  class StockPolicy < ApplicationPolicy
    self.module_key = "sales"
    self.submodule_key = "stock"
  end
end
