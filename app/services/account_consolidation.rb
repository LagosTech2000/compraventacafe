# Gives an account to movements that were registered without one
# (Control financiero → Consolidación, Fernando, 2026-10-25), so every
# balance is complete. Only payments and collections of the other modules
# can lack it (expenses, other income and transfers always have one).
#
# The account is the one chosen, or, with `by_method`, the one each
# movement's payment method suggests (MoneyAccount#default_for); a movement
# with no method (payrolls) or no suggestion keeps waiting.
#
# A category can be given too (Fernando, 2026-10-24), only to the records
# that have one (CATEGORIES: the payroll expenses, with Fincas' expense
# categories); the others keep as they are. Only the account and the
# category change, audited as a change of the record; all of it or nothing.
class AccountConsolidation
  MODELS = {
    "invoices" => "InvoicePayment", "hauler_payments" => "HaulerPayment", "loans" => "Loan", "loan_payments" => "LoanPayment",
    "payroll_payments" => "PayrollPayment", "payroll_expenses" => "PayrollExpense", "sale_payments" => "SalePayment"
  }.freeze
  SOURCES = MODELS.keys.freeze
  # The records that have a category, and its column.
  CATEGORIES = { "payroll_expenses" => :expense_category_id }.freeze
  # What each record's audit label reads, loaded at once.
  PRELOADS = {
    "invoices" => :invoice, "hauler_payments" => { hauler: :person }, "loans" => :person, "loan_payments" => { loan: :person },
    "payroll_payments" => { payroll: :farm }, "payroll_expenses" => { payroll: :farm }, "sale_payments" => { sale: :buyer }
  }.freeze

  # assigned: given an account; skipped: waiting for one (by method);
  # categorized: given the category; uncategorized: marked, without one.
  Result = Data.define(:assigned, :skipped, :categorized, :uncategorized)

  # items: ["invoices:12", "loans:4", ...]. account and category optional.
  def initialize(items:, account: nil, by_method: false, category: nil, sources: SOURCES)
    @items = Array(items).filter_map { |item| item.to_s.split(":", 2) }.select { |source, id| (sources & SOURCES).include?(source) && id.to_s.match?(/\A\d+\z/) }
    @account = account
    @by_method = by_method
    @category = category
  end

  def call
    defaults = MoneyAccount.defaults_by_method
    counts = Hash.new(0)
    ActiveRecord::Base.transaction do
      @items.group_by(&:first).each do |source, pairs|
        records = MODELS.fetch(source).constantize.where(id: pairs.map(&:last), money_account_id: nil).lock.to_a
        ActiveRecord::Associations::Preloader.new(records:, associations: PRELOADS.fetch(source)).call
        records.each { |record| consolidate(record, source, defaults, counts) }
      end
    end
    Result.new(assigned: counts[:assigned], skipped: counts[:skipped], categorized: counts[:categorized], uncategorized: counts[:uncategorized])
  end

  private
    def consolidate(record, source, defaults, counts)
      if @by_method || @account
        account_id = @by_method ? defaults[method_of(record)] : @account.id
        record.money_account_id = account_id if account_id
        counts[account_id ? :assigned : :skipped] += 1
      end
      if @category
        column = CATEGORIES[source]
        record[column] = @category.id if column
        counts[column ? :categorized : :uncategorized] += 1
      end
      # Only these: the record keeps everything else as it was.
      record.save!(validate: false) if record.changed?
    end

    # A loan's cash went out as cash; payrolls say no method.
    def method_of(record)
      return "cash" if record.is_a?(Loan)

      record.try(:payment_method)
    end
end
