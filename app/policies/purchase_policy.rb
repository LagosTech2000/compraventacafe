# An invoiced purchase is frozen for everyone, administrators too
# (Fernando, 2026-11-18: «que no se pueda editar ... ni compras»): it was
# already printed for the producer. To correct it, an administrator voids
# its invoice (which voids its purchases) and it is registered again. A
# voided one is kept only as a record. One that paid a loan keeps its
# amount (remove the loan payment first). Voiding takes the delete permission.
class PurchasePolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "purchases"

  def update?
    super && open?
  end

  def destroy?
    super && open?
  end

  def void?
    destroy?
  end

  private
    def open?
      unlocked? || !record.is_a?(Purchase) || !(record.invoiced? || record.voided? || record.loan_payments.any?)
    end
end
