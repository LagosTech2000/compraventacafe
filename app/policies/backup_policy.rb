# Downloading a copy of all the data: only the user who exports the data
# (User#data_exporter?), and only while an admin. Nobody else sees it.
class BackupPolicy < ApplicationPolicy
  self.module_key = "administration"

  def show? = admin?
  def create? = admin?

  def index? = false
  def update? = false
  def destroy? = false

  private
    def admin?
      user.present? && user.active? && user.admin? && user.data_exporter?
    end
end
