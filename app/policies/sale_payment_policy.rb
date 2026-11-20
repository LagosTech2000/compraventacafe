# Collecting a sale is changing it: it takes editing in Comercialización,
# as paying an invoice does in Compra de café. Payments are not edited, by
# anyone, and only the latest one can be removed (Fernando, 2026-11-18).
# An advance's collection is removed through its application.
class SalePaymentPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "sales"

  def create?
    can?(:update) && !(record.is_a?(SalePayment) && (record.sale.paid? || record.sale.voided?))
  end

  def update?
    false
  end

  def destroy?
    super && record.is_a?(SalePayment) && !record.sale.voided? && record.latest?
  end
end
