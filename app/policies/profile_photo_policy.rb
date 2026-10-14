# Profile photos (of people and users) are seen by every signed-in user: they
# show beside a name wherever it appears, in any module.
class ProfilePhotoPolicy < ApplicationPolicy
  def show? = user.present?
end
