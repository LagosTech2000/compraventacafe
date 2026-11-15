module Maintenance
  # integrity:shipment_expense_candidates — expenses of Control financiero
  # with no shipment, dated near a shipment (fuel, freight…), as
  # suggestions: someone confirms each one in «Asignar gastos» of the
  # shipment. Only expenses (not investments); optionally of some
  # categories (and their subcategories). Reads only.
  class ShipmentExpenseCandidates < Task
    self.key = "integrity:shipment_expense_candidates"
    self.tier = :check
    self.area = :sales
    param :days, :integer, default: 2
    param :category_ids, :ids

    def sections
      days = params["days"].to_i.clamp(0, 31)
      expenses = Expense.where(kind: "expense", shipment_id: nil).includes(:category)
      expenses = expenses.where(finance_category_id: category_family) if params["category_ids"]
      expenses = expenses.to_a
      shipments = Shipment.active.order(:departed_at, :id).to_a
      lines = shipments.filter_map do |shipment|
        departed = shipment.departed_at.in_time_zone.to_date
        near = expenses.select { (it.spent_on - departed).abs <= days }
        next if near.empty?

        t(:line, number: shipment.display_number, date: day(departed),
                 expenses: near.sort_by(&:spent_on).map { t(:expense, id: it.id, date: day(it.spent_on), category: it.category.full_name, amount: money(it.amount)) }.join("; "))
      end
      header = [ t(:criteria, days:, categories: category_names) ]
      [ section(t(:title), lines.any? ? "warn" : "ok", header + (lines.presence || [ t(:none) ])) ]
    end

    private
      def category_family
        ids = params["category_ids"]
        ids + FinanceCategory.where(parent_id: ids).pluck(:id)
      end

      def category_names
        return t(:all_categories) unless params["category_ids"]

        FinanceCategory.where(id: params["category_ids"]).map(&:full_name).sort.to_sentence
      end
  end
end
