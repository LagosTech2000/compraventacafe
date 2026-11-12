# Processing sites are Comercialización records: deactivated, never deleted.
class ProcessingSitePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "coffee_conversions"

  def destroy?
    false
  end
end
