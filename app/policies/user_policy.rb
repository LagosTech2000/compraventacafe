# User management is reserved to admins; module permissions do not grant it.
class UserPolicy < ApplicationPolicy
  self.module_key = "administration"

  %i[index? show? create? update? edit_password? reset_password?].each do |rule|
    define_method(rule) { admin? }
  end

  def destroy?
    false
  end

  private
    def admin?
      user.present? && user.active? && user.admin?
    end
end
