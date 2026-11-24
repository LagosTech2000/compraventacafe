# The day's fuel close (Fernando, 2026-11-23) is made from the daily close of
# Compra de café or of Comercialización: whoever sees either makes it; only
# an administrator takes it back.
class FuelDayClosePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "daily_close"

  def create? = user.present? && (user.can?("trading.daily_close", :read) || user.can?("sales.daily_close", :read))
  def destroy? = create? && admin?
end
