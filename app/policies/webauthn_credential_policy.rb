# Each user registers and removes their own passkeys, and only theirs.
class WebauthnCredentialPolicy < ApplicationPolicy
  def create? = user.present? && record.user == user
  def destroy? = create?
end
