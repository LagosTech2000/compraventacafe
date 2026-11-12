# Transfers between accounts are registered or removed, never edited.
class AccountTransferPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "accounts"

  def update?
    false
  end
end
