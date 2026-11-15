# Who may search each kind of a searchable picker: whoever can open a form
# that picks it (the lists were in those forms before). Several submodules'
# permissions, like ReportPolicy; every decision is still User#can?.
class PickerSearchPolicy < ApplicationPolicy
  # A purchase (Compra de café), a farm's owner (Fincas, or Administración → Fincas).
  def producers? = reads?("trading.purchases") || writes?("farms.farms") || writes?("administration.farms")

  # A loan's borrower; the other person of a merge (administrators); who
  # buys supplies sold apart (Insumos → Salidas).
  def people? = writes?("loans.loans") || writes?("administration.people") || writes?("sales.supplies")

  # A payroll's employee; an employee of the Planilla interna.
  def collaborators? = writes?("farms.payrolls") || writes?("finance.staff") || writes?("administration.people")

  private
    def reads?(permission_key) = user.present? && user.can?(permission_key, :read)

    def writes?(permission_key) = user.present? && (user.can?(permission_key, :create) || user.can?(permission_key, :update))
end
