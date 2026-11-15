# One run of a data maintenance task (Maintenance, Fernando, 2026-11-15):
# from Administración → Mantenimiento de datos (user 1) or its rake from
# the Render shell (no user). Keeps what it found (sections, shown again
# as it was) and, when it changed data, what it changed (changes_made), so
# «Deshacer» puts it back. The data it changes is audited by its own models.
class MaintenanceRun < ApplicationRecord
  MODES = %w[preview apply revert].freeze
  STATUSES = %w[ok warn bad failed].freeze

  belongs_to :user, optional: true
  belongs_to :reverted_run, class_name: "MaintenanceRun", optional: true

  validates :task_key, :mode, :status, presence: true
  validates :mode, inclusion: { in: MODES }
  validates :status, inclusion: { in: STATUSES }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def task = Maintenance.find(task_key)
  def apply? = mode == "apply"
  def preview? = mode == "preview"
  def failed? = status == "failed"
  def reverted? = reverted_at.present?
  def changed_something? = apply? && !failed? && changes_made.values.any?(&:present?)
  def revertible? = changed_something? && !reverted? && task&.revertible?

  # Its sections as they were saved: [{ "title", "status", "lines" }].
  def section_list = sections.map { Maintenance::Section.from_h(it) }

  def who = user&.name || I18n.t("maintenance.console")

  # «Revisión» for a check, «Vista previa» / «Aplicada» / «Deshecha» otherwise.
  def mode_label
    return I18n.t("maintenance.modes.check") if preview? && task && !task.changes_data?

    I18n.t("maintenance.modes.#{mode}")
  end

  # A preview from which its changes may be applied: not failed, of a task that changes data.
  def appliable? = preview? && !failed? && task&.changes_data?
end
