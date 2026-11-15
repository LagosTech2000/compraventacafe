# Expenses and investments are the same record but two tabs of Control
# financiero, each with its own permission (Fernando, 2026-11-12): the
# record's kind says which. Without a record (Expense, the class) it is
# the expenses' tab; the controller authorizes a new record of its kind.
class ExpensePolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "expenses"

  SUBMODULES = { "expense" => "expenses", "investment" => "investments" }.freeze

  def self.permission_key_for(kind) = "#{module_key}.#{SUBMODULES.fetch(kind)}"

  # An investment registered by a supplies' entry changes only through it
  # (Fernando, 2026-11-12).
  def update? = super && !from_supply_entry?
  def destroy? = super && !from_supply_entry?

  class Scope < ApplicationPolicy::Scope
    def resolve
      kinds = SUBMODULES.keys.select { |kind| user&.can?(ExpensePolicy.permission_key_for(kind), :read) }
      kinds.any? ? owned(scope.where(kind: kinds)) : scope.none
    end
  end

  private
    def from_supply_entry? = record.is_a?(Expense) && record.supply_entry.present?

    def permission_key
      record.is_a?(Expense) ? self.class.permission_key_for(record.kind) : super
    end
end
