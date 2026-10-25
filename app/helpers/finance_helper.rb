module FinanceHelper
  # Where a movement opens (MoneyMovements' route), only for who may read
  # the module it belongs to.
  def movement_path(movement)
    return unless movement.route && Current.user.can?(MoneyMovements::MODULES.fetch(movement.source), :read)

    public_send(*movement.route)
  end

  # Other income and transfers are removed from the ledger itself (they
  # have no page of their own).
  def movement_removal_path(movement)
    case movement.source
    when "other_incomes" then finance_other_income_path(movement.id) if policy(OtherIncome).destroy?
    when "transfers" then finance_account_transfer_path(movement.id) if policy(AccountTransfer).destroy?
    end
  end

  # "+L 1,000.00" / "−L 1,000.00"
  def signed_money(value)
    value.to_d.negative? ? "−#{format_money(value.to_d.abs)}" : format_money(value)
  end

  # Where a period of the Planilla interna stands: paid, to pay (its payday
  # came) or running.
  def staff_period_badge(member, period, today = Time.zone.today)
    key = if member.paid_period?(period) then "paid"
    elsif period.due?(today) then "due"
    else "running"
    end
    tag.span(t("finance.staff_members.period_status.#{key}"), class: "badge #{{ "paid" => "badge-success", "due" => "badge-danger", "running" => "badge-neutral" }[key]}")
  end

  # "L 6,000.00 quincenal"
  # Of a role, or of an employee (their own salary if they have one).
  def staff_salary(role_or_member)
    role = role_or_member.is_a?(StaffMember) ? role_or_member.role : role_or_member
    return t("finance.staff_roles.no_salary") unless role.priced?

    t("finance.staff_roles.salary_per", amount: format_money(role_or_member.salary), frequency: role.human_pay_frequency.downcase)
  end

  # "15", "12.5": days worked.
  def format_days(days) = number_with_precision(days, precision: 1, strip_insignificant_zeros: true)

  # The salary in an employee's row: theirs (marked «propio») or the role's.
  def staff_member_salary(member)
    return tag.span(t("finance.staff_roles.no_salary"), class: "badge badge-warning") unless member.salary

    safe_join([ format_money(member.salary), (tag.span(t("finance.staff_members.own_salary"), class: "badge badge-neutral") if member.own_salary?) ].compact, " ")
  end
end
