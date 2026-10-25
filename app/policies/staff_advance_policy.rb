# Advances of the Planilla interna: registered or removed (only while not
# taken off a payment), never edited.
class StaffAdvancePolicy < ApplicationPolicy
  self.module_key = "finance"

  def update?
    false
  end

  def destroy?
    super && record.is_a?(StaffAdvance) && !record.taken_off?
  end
end
