module Maintenance
  # integrity:expenses — expenses and investments to review: without their
  # receipt, possibly registered twice (same day, amount, category and
  # payee) or dated in the future. Never removes anything. Reads only.
  class Expenses < Task
    self.key = "integrity:expenses"
    self.tier = :check
    self.area = :finance

    def sections
      today = Time.zone.today
      without = Expense.where.missing(:receipt)
      total = Expense.count
      receipt_lines = [ t(:without_receipt, count: without.count, total:) ]
      receipt_lines += without.order(spent_on: :desc, id: :desc).limit(30).includes(:category).map { line(it) } if without.exists?

      twins = Expense.group(:spent_on, :amount, :finance_category_id, :payee).having("COUNT(*) > 1").pluck(Arel.sql("ARRAY_AGG(expenses.id ORDER BY expenses.id)"))
      twin_lines = twins.map { |ids| t(:twins, ids: ids.map { "##{it}" }.join(", "), first: line(Expense.includes(:category).find(ids.first))) }

      future = Expense.where(spent_on: (today + 1)..).includes(:category).order(:spent_on)
      [
        section(t(:receipts), without.exists? ? "warn" : "ok", receipt_lines),
        section(t(:duplicates), twins.any? ? "warn" : "ok", twin_lines.presence || [ t(:no_twins) ]),
        section(t(:future), future.exists? ? "bad" : "ok", future.map { line(it) }.presence || [ t(:no_future) ])
      ]
    end

    private
      def line(expense)
        t(:line, id: expense.id, kind: Expense.human_attribute_name("kind/#{expense.kind}"), date: day(expense.spent_on),
                 category: expense.category.full_name, amount: money(expense.amount))
      end
  end
end
