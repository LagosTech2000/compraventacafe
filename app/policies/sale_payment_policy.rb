# Collecting a sale is changing it: it takes editing in Comercialización,
# as paying an invoice does in Compra de café. Payments are never edited,
# and only the latest one can be removed.
class SalePaymentPolicy < ApplicationPolicy
  self.module_key = "sales"

  def create?
    can?(:update) && !(record.is_a?(SalePayment) && (record.sale.paid? || record.sale.voided?))
  end

  def update?
    false
  end

  def destroy?
    super && record.is_a?(SalePayment) && record.latest?
  end
end
