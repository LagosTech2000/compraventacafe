module Finance
  # The payroll sheet: reading it takes reading Control financiero; marking
  # attendance, editing; paying from it, creating (like a payment).
  class StaffSheetPolicy < ApplicationPolicy
    self.module_key = "finance"

    def pay? = can?(:create)
  end
end
