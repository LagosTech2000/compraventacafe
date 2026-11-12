# A purchase invoice whose coffee went on a shipment (Fernando, 2026-11-12),
# to know what the shipment cost. Each invoice goes whole to one shipment,
# and only to one of the same coffee state (every purchase of the invoice
# in that state). It gives the cost only: the inventory's lots do not
# change. Voiding the shipment lets its invoices go.
class ShipmentInvoice < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  belongs_to :shipment
  belongs_to :invoice
  belongs_to :created_by, class_name: "User"

  validates :invoice_id, uniqueness: true
  validate :same_coffee_state, :shipment_active, on: :create

  def audit_label = "#{invoice&.display_number} · #{shipment&.audit_label}"

  private
    def same_coffee_state
      return unless shipment && invoice

      errors.add(:invoice, :other_coffee_state) unless Invoice.of_coffee_state(shipment.coffee_state).exists?(invoice.id)
    end

    def shipment_active
      errors.add(:shipment, :voided) if shipment&.voided?
    end
end
