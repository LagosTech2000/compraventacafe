# Documentos privados (the promissory note and the loan contract): only
# admins see and edit their text (Fernando, 2026-10-22: legal text). The
# two documents are fixed: nobody adds or removes one.
class PrivateDocumentPolicy < ApplicationPolicy
  self.module_key = "administration"

  def index? = admin?
  def show? = admin?
  def update? = admin?

  def create? = false
  def destroy? = false

  private
    def admin?
      user.present? && user.active? && user.admin?
    end
end
