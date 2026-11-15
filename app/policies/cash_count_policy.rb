# Cash counts are Control financiero records: counted with the create
# permission, removed with delete, never edited.
class CashCountPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "accounts"

  def update?
    false
  end
end
