class PersonPolicy < ApplicationPolicy
  self.module_key = "administration"

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?(:administration, :read) ? scope.all : scope.none
    end
  end
end
