# Every signed-in user changes their own display settings, and only theirs.
class UserSettingPolicy < ApplicationPolicy
  def edit? = update?
  def update? = user.present? && record == user
end
