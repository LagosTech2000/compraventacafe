# Every peso that came into or went out of the business, from every module
# (Control financiero, Fernando, 2026-10-23: «se ven juntas, sin
# duplicar»): each is registered once, where it happens, and read here.
#
#   out  payments to producers on invoices, payments to haulers, cash lent,
#        payroll payments, payroll expenses, expenses and investments
#   in   loan payments in cash, transfer or check, collections of coffee
#        sales and other income
#   both transfers between accounts: out of one, into the other (the
#        business's totals leave them out: the money stays home)
#
# Loan payments with coffee or from a payroll move no money: not here.
# Each movement says its account (nil when it was registered without one).
class MoneyMovements
  SOURCES = %w[invoices hauler_payments loans loan_payments payroll_payments payroll_expenses
               sale_payments expenses investments other_incomes transfers].freeze
  # Which module each source's records belong to (who may read it).
  MODULES = {
    "invoices" => "trading", "hauler_payments" => "trading", "loans" => "loans", "loan_payments" => "loans",
    "payroll_payments" => "farms", "payroll_expenses" => "farms", "sale_payments" => "sales",
    "expenses" => "finance", "investments" => "finance", "other_incomes" => "finance", "transfers" => "finance"
  }.freeze
  NAME = "people.first_names || ' ' || people.last_names".freeze

  Movement = Data.define(:id, :date, :source, :description, :person, :payment_method, :amount_in, :amount_out,
                         :route, :account_id, :category, :account_name) do
    def net = amount_in - amount_out
    def direction = amount_in.positive? ? "in" : "out"
    def transfer? = source == "transfers"
    def key = "#{source}-#{id}-#{direction}"
  end

  # The sources a user may read (all of them without a user).
  def self.sources_for(user)
    return SOURCES if user.nil?

    SOURCES.select { |source| user.can?(MODULES.fetch(source), :read) }
  end

  # range: dates (open ends allowed; nil for all). account: an account id,
  # :none (without an account) or nil (any).
  def initialize(range: nil, account: nil, sources: SOURCES)
    @range = range
    @account = account
    @sources = sources
  end

  def all
    @all ||= begin
      names = MoneyAccount.pluck(:id, :name).to_h
      @sources.flat_map { |source| send(source) }
              .map { |movement| movement.account_id ? movement.with(account_name: names[movement.account_id]) : movement }
              .sort_by { |movement| [ movement.date, movement.source, movement.id ] }
    end
  end

  private
    def method_label(model, method) = method && model.human_attribute_name("payment_method/#{method}")

    def movement(**attributes)
      Movement.new(person: nil, payment_method: nil, amount_in: 0.to_d, amount_out: 0.to_d, route: nil, category: nil, account_name: nil, **attributes)
    end

    # A relation narrowed to the dates and the account.
    def narrowed(relation, date, account_column)
      relation = relation.where(date => @range) if @range
      case @account
      when nil then relation
      when :none then relation.where(account_column => nil)
      else relation.where(account_column => @account)
      end
    end

    def invoices
      narrowed(InvoicePayment.joins(invoice: { producer: :person }), "invoice_payments.paid_on", "invoice_payments.money_account_id")
        .pluck("invoice_payments.id", "invoice_payments.paid_on", "invoices.number", "invoice_payments.payment_method", Arel.sql(NAME),
               "invoice_payments.amount", "invoices.id", "invoice_payments.money_account_id")
        .map do |id, date, number, method, name, amount, invoice_id, account_id|
          movement(id:, date:, source: "invoices", description: I18n.t("money_movements.invoice", number: format("%04d", number)),
                   person: name, payment_method: method_label(Invoice, method), amount_out: amount, account_id:,
                   route: [ :trading_invoice_path, invoice_id ])
        end
    end

    def hauler_payments
      narrowed(HaulerPayment.joins(hauler: :person), "hauler_payments.paid_on", "hauler_payments.money_account_id")
        .pluck("hauler_payments.id", "hauler_payments.paid_on", "hauler_payments.payment_method", Arel.sql(NAME),
               "hauler_payments.amount", "hauler_payments.hauler_id", "hauler_payments.money_account_id")
        .map do |id, date, method, name, amount, hauler_id, account_id|
          movement(id:, date:, source: "hauler_payments", description: I18n.t("money_movements.hauler_payment", number: format("%04d", id)),
                   person: name, payment_method: method_label(Invoice, method), amount_out: amount, account_id:,
                   route: [ :trading_hauler_payment_path, hauler_id, id ])
        end
    end

    def loans
      narrowed(Loan.where("loans.cash_amount > 0").joins(:person), "loans.disbursed_on", "loans.money_account_id")
        .pluck("loans.id", "loans.disbursed_on", "loans.cash_amount", Arel.sql(NAME), "loans.money_account_id")
        .map do |id, date, amount, name, account_id|
          movement(id:, date:, source: "loans", description: I18n.t("money_movements.loan", number: id), person: name,
                   amount_out: amount, account_id:, route: [ :loans_loan_path, id ])
        end
    end

    def loan_payments
      narrowed(LoanPayment.where(payment_method: LoanPayment::PAYMENT_METHODS).joins(loan: :person), "loan_payments.paid_on",
               "loan_payments.money_account_id")
        .pluck("loan_payments.id", "loan_payments.loan_id", "loan_payments.paid_on", "loan_payments.amount", "loan_payments.payment_method",
               Arel.sql(NAME), "loan_payments.money_account_id")
        .map do |id, loan_id, date, amount, method, name, account_id|
          movement(id:, date:, source: "loan_payments", description: I18n.t("money_movements.loan_payment", number: format("%04d", id), loan: loan_id),
                   person: name, payment_method: method_label(LoanPayment, method), amount_in: amount, account_id:,
                   route: [ :loans_loan_payment_path, loan_id, id ])
        end
    end

    def payroll_payments
      narrowed(PayrollPayment.joins(payroll: :farm), "payroll_payments.paid_on", "payroll_payments.money_account_id")
        .pluck("payroll_payments.id", "payroll_payments.payroll_id", "payroll_payments.paid_on", "payroll_payments.net_total", "payrolls.name",
               "farms.name", "payroll_payments.period_starts_on", "payroll_payments.period_ends_on", "payroll_payments.money_account_id")
        .map do |id, payroll_id, date, amount, payroll, farm, from, to, account_id|
          period = I18n.t("farms.period", from: I18n.l(from, format: :short), to: I18n.l(to, format: :short))
          movement(id:, date:, source: "payroll_payments", description: I18n.t("money_movements.payroll_payment", payroll:, farm:, period:),
                   amount_out: amount, account_id:, route: [ :farms_payroll_payment_path, payroll_id, id ])
        end
    end

    def payroll_expenses
      narrowed(PayrollExpense.joins(:category, payroll: :farm), "payroll_expenses.spent_on", "payroll_expenses.money_account_id")
        .pluck("payroll_expenses.id", "payroll_expenses.spent_on", "payroll_expenses.amount", "payroll_expenses.description",
               "expense_categories.name", "farms.name", "payroll_expenses.payroll_id", "payroll_expenses.money_account_id")
        .map do |id, date, amount, description, category, farm, payroll_id, account_id|
          movement(id:, date:, source: "payroll_expenses", description: I18n.t("money_movements.payroll_expense", description:, farm:),
                   category:, amount_out: amount, account_id:, route: [ :farms_payroll_path, payroll_id, { tab: "expenses" } ])
        end
    end

    def sale_payments
      narrowed(SalePayment.joins(sale: :buyer).merge(Sale.active), "sale_payments.paid_on", "sale_payments.money_account_id")
        .pluck("sale_payments.id", "sale_payments.paid_on", "sales.number", "sale_payments.payment_method", "buyers.name",
               "sale_payments.amount", "sales.id", "sale_payments.money_account_id")
        .map do |id, date, number, method, name, amount, sale_id, account_id|
          movement(id:, date:, source: "sale_payments", description: I18n.t("money_movements.sale_payment", number: format("%04d", number)),
                   person: name, payment_method: method_label(Invoice, method), amount_in: amount, account_id:,
                   route: [ :sales_sale_payment_path, sale_id, id ])
        end
    end

    def expenses = spending("expense")
    def investments = spending("investment")

    def spending(kind)
      narrowed(Expense.where(kind:).joins(:category).left_joins(category: :parent), "expenses.spent_on", "expenses.money_account_id")
        .pluck("expenses.id", "expenses.spent_on", "expenses.description", "expenses.payee", "expenses.payment_method", "expenses.amount",
               Arel.sql("CONCAT_WS(' › ', parents_finance_categories.name, finance_categories.name)"), "expenses.money_account_id")
        .map do |id, date, description, payee, method, amount, category, account_id|
          movement(id:, date:, source: kind == "expense" ? "expenses" : "investments", description:, person: payee,
                   payment_method: method_label(Invoice, method), amount_out: amount, account_id:, category:,
                   route: [ kind == "expense" ? :finance_expense_path : :finance_investment_path, id ])
        end
    end

    def other_incomes
      narrowed(OtherIncome.all, "other_incomes.received_on", "other_incomes.money_account_id")
        .pluck(:id, :received_on, :concept, :payment_method, :amount, :money_account_id)
        .map do |id, date, concept, method, amount, account_id|
          movement(id:, date:, source: "other_incomes", description: concept, payment_method: method_label(Invoice, method),
                   amount_in: amount, account_id:, route: [ :finance_money_account_path, account_id ])
        end
    end

    # Two movements each: out of one account, into the other. With an
    # account chosen, only its side.
    def transfers
      relation = AccountTransfer.joins("JOIN money_accounts origin ON origin.id = account_transfers.from_account_id")
                                .joins("JOIN money_accounts destination ON destination.id = account_transfers.to_account_id")
      relation = relation.where(transferred_on: @range) if @range
      return [] if @account == :none

      relation.pluck("account_transfers.id", "account_transfers.transferred_on", "account_transfers.amount", "account_transfers.from_account_id",
                     "account_transfers.to_account_id", "origin.name", "destination.name")
              .flat_map do |id, date, amount, from_id, to_id, from_name, to_name|
                description = I18n.t("money_movements.transfer", from: from_name, to: to_name)
                [ (movement(id:, date:, source: "transfers", description:, amount_out: amount, account_id: from_id,
                            route: [ :finance_money_account_path, from_id ]) if @account.nil? || @account == from_id),
                  (movement(id:, date:, source: "transfers", description:, amount_in: amount, account_id: to_id,
                            route: [ :finance_money_account_path, to_id ]) if @account.nil? || @account == to_id) ].compact
              end
    end
end
