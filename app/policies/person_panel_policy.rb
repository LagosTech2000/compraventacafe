# The panel of a person opened by the fingerprint reader (Fernando,
# 2026-11-14): every signed-in user sees who it is (people are a shared
# catalog); each part (producer, loans, hauler, driver) and each shortcut
# asks its own tab's policy.
class PersonPanelPolicy < ApplicationPolicy
  def show? = user.present? && user.active?
end
