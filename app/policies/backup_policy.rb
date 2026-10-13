# Downloading a copy of all the data: admins only, like user management.
class BackupPolicy < ApplicationPolicy
  self.module_key = "administration"

  def show? = admin?
  def create? = admin?

  def index? = false
  def update? = false
  def destroy? = false

  private
    def admin?
      user.present? && user.active? && user.admin?
    end
end
