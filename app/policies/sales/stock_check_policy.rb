module Sales
  # Why the stock's net pounds are not the expected ones (sales/stock_checks):
  # administrators who see the stock (Fernando, 2026-11-16: «un link que
  # explique todas esas cosas a los admin»).
  class StockCheckPolicy < ApplicationPolicy
    self.module_key = "sales"
    self.submodule_key = "stock"

    def show? = admin? && super
  end
end
