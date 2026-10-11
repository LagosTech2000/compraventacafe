# The business's name, location and logo: admins only, like user management.
class SiteSettingPolicy < ApplicationPolicy
  self.module_key = "administration"

  def show? = admin?
  def update? = admin?

  def index? = false
  def create? = false
  def destroy? = false

  private
    def admin?
      user.present? && user.active? && user.admin?
    end
end
