# Collecting a sale is changing it: it takes editing in Comercialización,
# as paying an invoice does in Compra de café. Payments are not edited and
# only the latest one can be removed, except by an administrator: any one,
# edited or removed (Fernando, 2026-11-12).
class SalePaymentPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "sales"

  def create?
    can?(:update) && !(record.is_a?(SalePayment) && (record.sale.paid? || record.sale.voided?))
  end

  # An advance's collection is changed through its application.
  def update?
    admin? && record.is_a?(SalePayment) && !record.sale.voided? && !record.advance?
  end

  def destroy?
    super && record.is_a?(SalePayment) && !record.sale.voided? && (record.latest? || admin?)
  end
end
