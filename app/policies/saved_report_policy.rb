# Saved filters are each user's own: whoever can read reports saves theirs,
# and only sees and removes their own.
class SavedReportPolicy < ApplicationPolicy
  self.module_key = "reports"

  def index? = can?(:read)
  def create? = can?(:read)
  def destroy? = can?(:read) && record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?("reports", :read) ? scope.where(user:) : scope.none
    end
  end
end
