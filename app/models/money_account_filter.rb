class MoneyAccountFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :kind, :choice, in: MoneyAccount::KINDS
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("money_accounts.name"), kind: "money_accounts.kind", bank_name: text("money_accounts.bank_name"),
        account_number: "money_accounts.account_number", opening_on: "money_accounts.opening_on",
        balance: { ruby: ->(account) { account.balance } }

  def apply(scope)
    scope = scope.where("money_accounts.name ILIKE :q OR money_accounts.bank_name ILIKE :q OR money_accounts.account_number ILIKE :q", q: like(q)) if q
    scope = scope.where(kind:) if kind
    scope = scope.where(active: status == "active") if status
    # The cash box first: it is the most used (Fernando, 2026-10-24).
    scope.order(Arel.sql("CASE WHEN money_accounts.kind = 'cash' THEN 0 ELSE 1 END"), :name)
  end
end
