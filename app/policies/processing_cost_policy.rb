# What processing cost (Comercialización): registered with the create
# permission while the process is not voided, removed with the delete one.
# Never edited.
class ProcessingCostPolicy < ApplicationPolicy
  self.module_key = "sales"

  def create?
    super && (!record.is_a?(ProcessingCost) || !record.coffee_conversion&.voided?)
  end

  def update?
    false
  end
end
