# Expenses or investments of Control financiero (the kind comes from the
# screen): this month by default.
class ExpenseFilter < ListFilter
  field :from, :date, default: -> { Time.zone.today.beginning_of_month }
  field :to, :date, default: -> { Time.zone.today }
  field :q, :text
  field :category_id, :id
  field :money_account_id, :id
  field :payment_method, :choice, in: Invoice::PAYMENT_METHODS

  sorts spent_on: "expenses.spent_on",
        description: text("expenses.description"),
        payee: text("expenses.payee"),
        category: { sql: text("finance_categories.name"), joins: :category },
        account: { sql: text("money_accounts.name"), joins: :money_account },
        payment_method: "expenses.payment_method",
        receipt_number: "expenses.receipt_number",
        amount: "expenses.amount"

  def apply(scope)
    scope = scope.where(spent_on: from..to) if from || to
    if q
      scope = scope.where("expenses.description ILIKE :q OR expenses.payee ILIKE :q OR expenses.receipt_number ILIKE :q", q: like(q))
    end
    if category_id
      scope = scope.where(finance_category_id: FinanceCategory.where(id: category_id).or(FinanceCategory.where(parent_id: category_id)).select(:id))
    end
    scope = scope.where(money_account_id:) if money_account_id
    scope = scope.where(payment_method:) if payment_method
    scope.includes(:money_account, :receipt_info, category: :parent).newest_first
  end
end
