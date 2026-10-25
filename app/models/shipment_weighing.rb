# One weighing of a truck on the local scale, when it is weighed by
# weighings: its weight and the sacks counted. The shipment sums them.
class ShipmentWeighing < ApplicationRecord
  include Auditable

  belongs_to :shipment

  validates :gross_weight, numericality: { greater_than: 0, less_than: Shipment::MAX_WEIGHT }
  validates :sacks, numericality: { only_integer: true, greater_than: 0, less_than: Shipment::MAX_SACKS }

  def audit_label = "#{self.class.model_name.human} · #{shipment&.audit_label}"
end
