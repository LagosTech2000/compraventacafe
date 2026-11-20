module Sales
  # The day's reconciliation (Fernando, 2026-11-18): whoever sees Inventario.
  class StockReconciliationPolicy < ApplicationPolicy
    self.module_key = "sales"
    self.submodule_key = "stock"
  end
end
