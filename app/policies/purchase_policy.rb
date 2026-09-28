# An invoiced purchase is frozen: it was already printed for the producer.
class PurchasePolicy < ApplicationPolicy
  self.module_key = "trading"

  def update?
    super && !invoiced?
  end

  def destroy?
    super && !invoiced?
  end

  private
    def invoiced?
      record.is_a?(Purchase) && record.invoiced?
    end
end
