# Cash counts are Control financiero records: counted with the create
# permission, removed with delete, never edited.
class CashCountPolicy < ApplicationPolicy
  self.module_key = "finance"

  def update?
    false
  end
end
