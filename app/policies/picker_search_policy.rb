# Who may search each kind of a searchable picker: whoever can open a form
# that picks it (the lists were in those forms before). Several modules'
# permissions, like ReportPolicy; every decision is still User#can?.
class PickerSearchPolicy < ApplicationPolicy
  # A purchase (Compra de café), a farm's owner (Fincas, or Administración → Fincas).
  def producers? = reads?("trading") || writes?("farms") || writes?("administration")

  # A loan's borrower; the other person of a merge (administrators).
  def people? = writes?("loans") || writes?("administration")

  # A payroll's employee.
  def collaborators? = writes?("farms") || writes?("administration")

  private
    def reads?(module_key) = user.present? && user.can?(module_key, :read)

    def writes?(module_key) = user.present? && (user.can?(module_key, :create) || user.can?(module_key, :update))
end
