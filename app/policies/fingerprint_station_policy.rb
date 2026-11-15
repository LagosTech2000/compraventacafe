# The PCs with a fingerprint reader (Fernando, 2026-11-14): administrators
# create, pair, link and deactivate them.
class FingerprintStationPolicy < ApplicationPolicy
  self.module_key = "administration"

  def index? = admin?
  def show? = admin?
  def create? = admin?
  def destroy? = admin? && record.is_a?(FingerprintStation) && record.active?
  def link? = destroy?
  def pairing? = destroy?

  private
    def admin? = user.present? && user.active? && user.admin?
end
