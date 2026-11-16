# The owners' loans (Control financiero → Préstamos de los dueños, a
# development quoted apart: off, User#can? says no). Edited while it has no
# payments; never deleted.
class OwnerLoanPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "owner_loans"

  def update? = super && (!record.is_a?(OwnerLoan) || record.payments.none?)
  def destroy? = false
end
