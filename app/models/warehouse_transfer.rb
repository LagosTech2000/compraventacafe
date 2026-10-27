# Coffee moved from one warehouse to another (client, 2026-10-26: «café que
# se mueve de una bodega a otra»), with its history. It is written in net
# pounds of one coffee state (decision of implementation, pending to
# confirm); the oldest lots of that state in the warehouse go first and
# keep their date (CoffeeLots). Its gross pounds are the net ones at the
# warehouse's net/gross proportion of that state that day, kept so the
# kardex does not change afterwards.
#
# Taking more than the warehouse has warns, it does not stop it (as the
# shipments). Voided, never deleted: the coffee goes back.
class WarehouseTransfer < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  NUMBERING_LOCK_KEY = 7_301_006
  MAX_WEIGHT = 1_000_000_000

  belongs_to :from_warehouse, class_name: "Warehouse"
  belongs_to :to_warehouse, class_name: "Warehouse"
  belongs_to :created_by, class_name: "User"
  belongs_to :voided_by, class_name: "User", optional: true

  normalizes :observations, with: FieldFormats::STRIP

  validates :transferred_at, presence: true
  validates :coffee_state, inclusion: { in: Purchase::COFFEE_STATES }
  validates :net_weight, numericality: { greater_than: 0, less_than: MAX_WEIGHT }
  validates :observations, length: { maximum: 500 }
  validate :different_warehouses
  validate :warehouses_active, on: :create

  before_validation :weigh, if: -> { new_record? || will_save_change_to_net_weight? || will_save_change_to_transferred_at? }
  before_create :assign_number

  scope :active, -> { where(voided_at: nil) }
  scope :newest_first, -> { order(transferred_at: :desc, id: :desc) }

  def display_number = format("%04d", number)
  def audit_label = "#{display_number} · #{from_warehouse&.name} → #{to_warehouse&.name}"
  def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
  def quintals = PurchaseCalculation.quintals(net_weight)
  def voided? = voided_at.present?

  def void!(user)
    raise ActiveRecord::RecordInvalid, tap { errors.add(:base, :voided) } if voided?

    update!(voided_at: Time.current, voided_by: user)
  end

  # Net/gross proportion of a state in a warehouse on a day; without coffee
  # there, the business's (CoffeeConversion.ratio_for).
  def self.ratio_for(state, warehouse, date)
    row = CoffeeStock.new(date, warehouse:).row(state)
    return (row.stock / row.gross_stock).round(6) if row.stock.positive? && row.gross_stock.positive?

    CoffeeConversion.ratio_for(state, date).first
  end

  private
    def weigh
      return unless from_warehouse && coffee_state.in?(Purchase::COFFEE_STATES) && transferred_at && net_weight.to_d.positive?

      ratio = self.class.ratio_for(coffee_state, from_warehouse, transferred_at.to_date)
      self.gross_weight = ratio.positive? ? (net_weight / ratio).round(2) : net_weight
    end

    def different_warehouses
      errors.add(:to_warehouse, :same) if from_warehouse_id && from_warehouse_id == to_warehouse_id
    end

    def warehouses_active
      errors.add(:from_warehouse, :inactive) if from_warehouse && !from_warehouse.active?
      errors.add(:to_warehouse, :inactive) if to_warehouse && !to_warehouse.active?
    end

    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end
end
