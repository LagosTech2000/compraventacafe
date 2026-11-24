# «Confirmar cierre» (Fernando, 2026-11-23): who marked a module's daily
# close of a day as reviewed, and when. It does not lock anything (the
# business's lock is BusinessDayClose); one per module and day.
class DailyCloseConfirmation < ApplicationRecord
  include Auditable

  MODULES = %w[trading sales loans].freeze

  belongs_to :confirmed_by, class_name: "User"

  validates :module_key, inclusion: { in: MODULES }
  validates :day, presence: true, uniqueness: { scope: :module_key }
  validates :day, not_in_future: true

  def self.for(module_key, day) = find_by(module_key: module_key.to_s, day:)

  def audit_label = "#{I18n.t("app_modules.#{module_key}")} · #{I18n.l(day)}"
end
