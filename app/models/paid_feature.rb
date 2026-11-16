# A development quoted apart (Fernando, 2026-11-15: «llevar el control de
# los desarrollos que son cotizados aparte»). The catalog lives here: what
# it does, the submodules it opens, the estimated hours and how useful it
# is; the record keeps whether it is on, its agreed price and notes.
# Suggested value = hours × the hourly rate of the control center
# (ControlSetting). Only User::DATA_EXPORTER_ID sees and turns them on.
#
# The submodule of a development that is off exists for nobody but that
# user: User#can? says no even to administrators, and it leaves menus, tabs
# and the permission screens (AppModule.offered_submodules).
class PaidFeature < ApplicationRecord
  include Auditable

  USEFULNESS = %w[high medium low].freeze

  Entry = Data.define(:key, :submodules, :hours, :usefulness)

  CATALOG = [
    Entry.new(key: "fingerprints", submodules: [], hours: 40, usefulness: "high"),
    Entry.new(key: "owner_loans", submodules: %w[finance.owner_loans], hours: 14, usefulness: "medium")
  ].freeze

  belongs_to :enabled_by, class_name: "User", optional: true

  validates :key, inclusion: { in: CATALOG.map(&:key) }, uniqueness: true
  validates :agreed_price, numericality: { greater_than_or_equal_to: 0, less_than: 10**9 }, allow_nil: true
  validates :notes, length: { maximum: 1_000 }

  before_save :stamp_enabled, if: :will_save_change_to_enabled?

  def self.entry(key) = CATALOG.find { it.key == key.to_s }

  # One record per development of the catalog (created off when missing).
  def self.ensure_all!
    CATALOG.each { |entry| find_or_create_by!(key: entry.key) }
    order(:id).to_a.sort_by { |record| CATALOG.index { it.key == record.key } || CATALOG.size }
  end

  # The submodules ("module.submodule") of the developments that are off.
  def self.locked_submodules
    on = where(enabled: true).pluck(:key)
    CATALOG.reject { on.include?(it.key) }.flat_map(&:submodules)
  end

  # Read once per request.
  def self.locked?(permission_key) = (Current.locked_submodules ||= locked_submodules).include?(permission_key.to_s)

  def entry = self.class.entry(key)
  def title = I18n.t("paid_features.catalog.#{key}.title")
  def description = I18n.t("paid_features.catalog.#{key}.description")
  def hours = entry.hours
  def usefulness = entry.usefulness
  def suggested_value(rate = ControlSetting.current.hourly_rate) = (hours * rate.to_d).round(2)
  def audit_label = title

  private
    def stamp_enabled
      self.enabled_at = enabled ? Time.current : nil
      self.enabled_by = enabled ? Current.user : nil
    end
end
