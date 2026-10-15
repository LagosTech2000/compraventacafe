module Administration
  # Merging two people into one (Fernando, 2026-10-14): administrators only,
  # because it cannot be undone.
  class PersonMergePolicy < ApplicationPolicy
    self.module_key = "administration"

    def new? = user&.active? && user.admin?
    def create? = new?
  end
end
