# One supply of an exit (Fernando, 2026-11-16: «que se pongan múltiples
# insumos así como en entrada»): how much left and, in a sale, its price
# per unit and amount (quantity × price).
class SupplyExitLine < ApplicationRecord
  include Auditable

  belongs_to :supply_exit, inverse_of: :lines
  belongs_to :supply

  validates :quantity, numericality: { greater_than: 0, less_than: SupplyExit::MAX_QUANTITY }
  validates :unit_price, numericality: { greater_than: 0, less_than: Supply::MAX_PRICE }, if: -> { supply_exit&.sale? }
  validate :supply_active, on: :create

  def audit_label = "#{supply&.name} × #{quantity}"

  # «Urea × 3 saco».
  def summary
    quantity_text = ActiveSupport::NumberHelper.number_to_rounded(quantity.to_d, precision: 2, strip_insignificant_zeros: true, delimiter: ",")
    I18n.t("sales.supply_entries.line", supply: supply&.name, quantity: quantity_text, unit: supply&.unit)
  end

  private
    def supply_active
      errors.add(:supply, :inactive) if supply && !supply.active?
    end
end
