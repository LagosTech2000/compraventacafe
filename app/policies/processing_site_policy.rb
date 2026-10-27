# Processing sites are Comercialización records: deactivated, never deleted.
class ProcessingSitePolicy < ApplicationPolicy
  self.module_key = "sales"

  def destroy?
    false
  end
end
