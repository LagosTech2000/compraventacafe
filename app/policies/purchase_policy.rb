# An invoiced purchase is frozen: it was already printed for the producer;
# only an administrator edits it, even if its invoice is paid (Fernando,
# 2026-11-12; voiding goes with its invoice). A voided one is kept only as
# a record. One that paid a loan keeps its amount (remove the loan payment
# first). Voiding takes the delete permission.
class PurchasePolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "purchases"

  def update?
    super && (open? || admin_revision?)
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

    def admin_revision?
      admin? && record.is_a?(Purchase) && record.invoiced? && !record.voided? && !record.invoice.voided? && record.loan_payments.none?
    end
end
