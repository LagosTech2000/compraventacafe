# Cash counts are Control financiero records: counted with the create
# permission, removed with delete (only the latest of its account: the
# ones after took its adjustment), never edited.
class CashCountPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "accounts"

  def update?
    false
  end

  def destroy?
    super && (!record.is_a?(CashCount) || record.latest?)
  end
end
