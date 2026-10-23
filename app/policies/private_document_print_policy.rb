# Printing a private document for a person, from their credit account:
# whoever can lend (create in Préstamos). The counter of prints is for
# everyone who sees the account; when and by whom, only for admins
# (Fernando, 2026-10-22).
class PrivateDocumentPrintPolicy < ApplicationPolicy
  self.module_key = "loans"

  def new? = create?
  def create? = can?(:create)
  # A print as it went out: who can print, and admins.
  def show? = create? || admin?
  def history? = admin?

  def index? = false
  def update? = false
  def destroy? = false

  private
    def admin?
      user.present? && user.active? && user.admin?
    end
end
