# People's fingerprints (Fernando, 2026-11-14): only administrators register,
# see or remove them.
class FingerprintPolicy < ApplicationPolicy
  self.module_key = "administration"

  def index? = admin?
  def show? = admin?
  def create? = admin?
  def destroy? = admin?

  private
    def admin? = user.present? && user.active? && user.admin?
end
