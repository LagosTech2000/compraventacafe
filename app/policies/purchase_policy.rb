# An invoiced purchase is frozen: it was already printed for the producer.
# A voided one is kept only as a record. Voiding takes the delete permission.
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
      !record.is_a?(Purchase) || !(record.invoiced? || record.voided?)
    end
end
