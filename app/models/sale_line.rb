# A shipment in a sale, with its weights and amount as they were charged.
# Active while the sale is not voided: a shipment is in one active line at
# most (unique index), so it is never sold twice.
class SaleLine < ApplicationRecord
  include Auditable

  belongs_to :sale, inverse_of: :lines
  belongs_to :shipment, inverse_of: :sale_lines

  validates :net_weight, :origin_net_weight, :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  def audit_label = "#{sale&.display_number} · #{I18n.t("sales.shipments.show.title", number: shipment&.display_number)}"
end
