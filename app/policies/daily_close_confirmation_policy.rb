# «Confirmar cierre» (Fernando, 2026-11-23): whoever sees a module's daily
# close confirms it; only an administrator takes a confirmation back.
class DailyCloseConfirmationPolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "daily_close"

  def create? = can?(:read)
  def destroy? = can?(:read) && admin?

  private
    def permission_key
      module_key = record.is_a?(DailyCloseConfirmation) ? record.module_key : nil
      module_key.in?(DailyCloseConfirmation::MODULES) ? "#{module_key}.daily_close" : super
    end
end
