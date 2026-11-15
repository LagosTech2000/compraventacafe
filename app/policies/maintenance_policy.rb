# Data maintenance tasks (Administración → Mantenimiento de datos, Fernando,
# 2026-11-15): only the user who exports the data (User#data_exporter?,
# id 1), and only while an administrator, like the backup. Nobody else
# sees them.
class MaintenancePolicy < ApplicationPolicy
  self.module_key = "administration"

  def index? = allowed?
  def show? = allowed?
  def create? = allowed?
  def revert? = allowed?

  def update? = false
  def destroy? = false

  private
    def allowed? = user.present? && user.active? && user.admin? && user.data_exporter?
end
