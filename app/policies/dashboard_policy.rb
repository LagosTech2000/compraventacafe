# The home page is open to every signed-in user; it only lists the modules
# each one can read.
class DashboardPolicy < ApplicationPolicy
  def show?
    user.present?
  end
end
