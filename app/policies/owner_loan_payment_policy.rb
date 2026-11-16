# A payment of an owners' loan: registered with «crear» on its tab, and only
# the last one is removed («borrar»).
class OwnerLoanPaymentPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "owner_loans"

  def destroy? = super && (!record.is_a?(OwnerLoanPayment) || record.latest?)
end
