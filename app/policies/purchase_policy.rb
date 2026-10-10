# An invoiced purchase is frozen: it was already printed for the producer.
# A voided one is kept only as a record. One that paid a loan keeps its
# amount (remove the loan payment first). Voiding takes the delete permission.
class PurchasePolicy < ApplicationPolicy
  self.module_key = "trading"

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
      !record.is_a?(Purchase) || !(record.invoiced? || record.voided? || record.loan_payments.any?)
    end
end
