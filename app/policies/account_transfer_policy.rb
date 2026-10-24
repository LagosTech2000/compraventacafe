# Transfers between accounts are registered or removed, never edited.
class AccountTransferPolicy < ApplicationPolicy
  self.module_key = "finance"

  def update?
    false
  end
end
