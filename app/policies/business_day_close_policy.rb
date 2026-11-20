# «Cierre del día» (Fernando, 2026-11-18): an administrator closes a day
# for the whole business; only the main user (id 1, like the backup)
# reopens the latest one, with a reason.
class BusinessDayClosePolicy < ApplicationPolicy
  self.module_key = "administration"

  def index? = admin?
  def create? = admin?
  def reopen? = admin? && user.data_exporter?

  def show? = false
  def update? = false
  def destroy? = false

  private
    def admin? = user.present? && user.active? && user.admin?
end
