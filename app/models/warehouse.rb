# Where the coffee is kept (client, 2026-10-26): «Bodega 1», «Bodega 2»…,
# renamed at will. One is the default (`main`): purchases start in it.
# Every purchase comes into a warehouse, every shipment and conversion takes
# coffee out of one, a conversion's result comes into one, and transfers
# move coffee between them (WarehouseTransfer).
#
# One that nothing uses is deleted; one that was used is deactivated, and
# only when it has no coffee left and is not the default (decision of
# implementation, pending to confirm).
class Warehouse < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  has_many :purchases, dependent: :restrict_with_error
  has_many :shipments, dependent: :restrict_with_error
  has_many :coffee_conversions, dependent: :restrict_with_error
  has_many :conversion_results, class_name: "CoffeeConversion", foreign_key: :output_warehouse_id, dependent: :restrict_with_error,
                                inverse_of: :output_warehouse
  has_many :transfers_out, class_name: "WarehouseTransfer", foreign_key: :from_warehouse_id, dependent: :restrict_with_error,
                           inverse_of: :from_warehouse
  has_many :transfers_in, class_name: "WarehouseTransfer", foreign_key: :to_warehouse_id, dependent: :restrict_with_error,
                          inverse_of: :to_warehouse

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { case_sensitive: false }
  validates :observations, length: { maximum: 500 }
  validate :main_is_active
  validate :empty_to_deactivate, if: -> { will_save_change_to_active? && !active? }

  # Only one is the default: choosing another one takes it off the rest.
  before_save { Warehouse.where.not(id:).where(main: true).update_all(main: false) if main? && will_save_change_to_main? }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  # The default one, or nil when there is none yet (a new database).
  def self.main = find_by(main: true)

  # The default one, created as «Bodega 1» when there is none (a database
  # loaded from the schema has no warehouses).
  def self.main!
    main || find_by(name: I18n.t("sales.warehouses.first_name")) || create!(name: I18n.t("sales.warehouses.first_name"), main: true)
  rescue ActiveRecord::RecordNotUnique
    main || find_by!(name: I18n.t("sales.warehouses.first_name"))
  end

  # Active ones, and the one already chosen even if not, for a select.
  def self.options_for(selected_id)
    active.or(where(id: selected_id)).alphabetical
  end

  def audit_label = name

  # Nothing points to it: it can be deleted instead of deactivated.
  def unused?
    [ purchases, shipments, coffee_conversions, conversion_results, transfers_out, transfers_in ].none?(&:exists?)
  end

  private
    def main_is_active
      errors.add(:base, :main_inactive) if main? && !active?
    end

    def empty_to_deactivate
      errors.add(:base, :has_coffee) if CoffeeStock.new(warehouse: self).rows.any? { it.stock.positive? }
    end
end
