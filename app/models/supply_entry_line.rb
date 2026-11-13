# One supply of an entry (Fernando, 2026-11-13: «por cada entrada puede
# haber múltiples insumos»): how much came in and what it cost.
class SupplyEntryLine < ApplicationRecord
  include Auditable

  belongs_to :supply_entry, inverse_of: :lines
  belongs_to :supply

  validates :quantity, numericality: { greater_than: 0, less_than: 100_000 }
  validates :amount, numericality: { greater_than: 0, less_than: Expense::MAX_AMOUNT }
  validate :supply_active, on: :create

  def audit_label = "#{supply&.name} × #{quantity}"
  def unit_cost = quantity.to_d.positive? ? (amount.to_d / quantity.to_d).round(4) : nil

  private
    def supply_active
      errors.add(:supply, :inactive) if supply && !supply.active?
    end
end
