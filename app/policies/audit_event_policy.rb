# The audit log shows every change, users included: admins only, like user
# management. Nobody edits or deletes it.
class AuditEventPolicy < ApplicationPolicy
  self.module_key = "administration"

  def index? = admin?
  def show? = admin?

  def create? = false
  def update? = false
  def destroy? = false

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.active? && user.admin? ? scope.all : scope.none
    end
  end

  private
    def admin?
      user.present? && user.active? && user.admin?
    end
end
