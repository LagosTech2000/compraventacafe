# One weighing of a purchase entered by weighings: its weight on the scale and
# the sacks counted in it. The purchase sums them (see Purchase).
class PurchaseWeighing < ApplicationRecord
  include Auditable

  MAX_SACKS = 10_000

  belongs_to :purchase

  validates :gross_weight, numericality: { greater_than: 0, less_than: 100_000 }
  validates :sacks, numericality: { only_integer: true, greater_than: 0, less_than: MAX_SACKS }

  def audit_label
    "#{self.class.model_name.human} · #{purchase&.audit_label}"
  end
end
