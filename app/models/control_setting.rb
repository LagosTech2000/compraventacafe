# What the control center sets globally (Fernando, 2026-11-15): the hourly
# rate the developments quoted apart are valued with. One row.
class ControlSetting < ApplicationRecord
  include Auditable

  validates :hourly_rate, numericality: { greater_than: 0, less_than: 10**7 }

  def self.current = first || create!(hourly_rate: 100)

  def audit_label = I18n.t("administration.control_centers.show.settings")
end
