module Sales
  class DailyClosePolicy < ApplicationPolicy
    self.module_key = "sales"
    self.submodule_key = "daily_close"
  end
end
