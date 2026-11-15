module Finance
  # Seeing what lacks an account takes reading Control financiero; giving
  # it one, editing there.
  class ConsolidationPolicy < ApplicationPolicy
    self.module_key = "finance"
    self.submodule_key = "consolidation"
  end
end
