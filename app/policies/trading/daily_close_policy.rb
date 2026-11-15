module Trading
  class DailyClosePolicy < ApplicationPolicy
    self.module_key = "trading"
    self.submodule_key = "daily_close"
  end
end
