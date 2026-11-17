# Records a user registers (Fernando, 2026-11-13: «los administradores ven
# todos los datos del sistema, y los usuarios con permisos granulares solo
# podrán ver los creados por ellos mismos»). Who is not an administrator
# sees, and works on, only the ones they registered (`created_by`): in
# lists, details, summaries, the Inicio, daily closes and reports. What is
# inside a record of theirs (its payments, lines) shows with it, whoever
# registered it. Catalogs (people, producers, zones, buyers, supplies,
# accounts) are shared; the coffee and supplies stock and the accounts'
# balances are of the whole business.
#
# `owned`: the ones of the user of the request (Current.owner; everything
# outside a request or for an administrator). `visible_to(user)`: the ones
# a user may see. Policies use OwnedRecord.visible? for each record.
module OwnedRecord
  extend ActiveSupport::Concern

  # The record a child belongs to: seeing or adding a child goes with it.
  PARENTS = {
    "InvoicePayment" => :invoice, "LoanPayment" => :loan, "SalePayment" => :sale, "ShipmentCost" => :shipment,
    "ProcessingCost" => :coffee_conversion, "CoffeeBatchInvoice" => :coffee_batch, "CoffeeBatchConversion" => :coffee_batch, "PayrollPayment" => :payroll,
    "PayrollExpense" => :payroll, "LoanSupply" => :loan, "SupplyEntryLine" => :supply_entry, "ShipmentWeighing" => :shipment,
    "SaleLine" => :sale, "PurchaseWeighing" => :purchase, "PayrollMember" => :payroll, "PayrollTask" => :payroll,
    "PayrollRole" => :payroll, "OwnerLoanPayment" => :owner_loan, "ExpenseReceipt" => :owner
  }.freeze

  included do
    scope :owned, -> { (owner = Current.owner) && OwnedRecord.restricted?(owner) ? where(created_by_id: owner.id) : all }
  end

  class_methods do
    def visible_to(user) = OwnedRecord.restricted?(user) ? where(created_by_id: user.id) : all
  end

  def self.restricted?(user) = user.present? && !user.admin?

  # Whether a user may see (and work on) a record: theirs, or inside one of
  # theirs; a new record of a kind they register, or inside one of theirs.
  def self.visible?(record, user)
    return true unless restricted?(user) && record.is_a?(ActiveRecord::Base)

    parent = parent_of(record)
    if record.class.include?(OwnedRecord)
      return true if record.created_by_id == user.id
      return visible?(parent, user) if parent
      return record.new_record? && record.created_by_id.nil?
    end
    parent ? visible?(parent, user) : true
  end

  def self.parent_of(record)
    association = PARENTS[record.class.name]
    association && record.respond_to?(association) ? record.public_send(association) : nil
  end
end
