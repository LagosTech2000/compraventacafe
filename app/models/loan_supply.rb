# A line of supplies in a loan: how much of a supply was lent and at what
# price. The price starts at the supply's default and is kept here, so the
# loan does not change if the default changes later.
class LoanSupply < ApplicationRecord
  include Auditable

  belongs_to :loan
  belongs_to :supply

  validates :quantity, numericality: { greater_than: 0, less_than: 100_000 }
  validates :unit_price, numericality: { greater_than: 0, less_than: Supply::MAX_PRICE }

  before_validation :compute_total

  def audit_label
    "#{supply&.name} · #{loan&.audit_label}"
  end

  # quantity × unit price, to the cent; nil until both are known.
  def self.total_for(quantity, unit_price)
    (quantity.to_d * unit_price.to_d).round(2) if quantity.present? && unit_price.present?
  end

  private
    def compute_total
      self.total = self.class.total_for(quantity, unit_price)
    end
end
