module Sales
  # Expenses of Control financiero assigned to a shipment (Fernando,
  # 2026-11-12): chosen from the expenses on no shipment, with the
  # expenses' filters (this month by default), marked and assigned at once.
  # Each expense goes to one shipment; it is let go apart. It stays an
  # expense of Control financiero: no money moves.
  class ShipmentExpensesController < ApplicationController
    before_action :set_shipment

    def new
      authorize @shipment, :create?, policy_class: ShipmentExpensePolicy
      @filter = ExpenseFilter.new(params)
      @expenses, @next_page = @filter.results(eligible)
    end

    def create
      authorize @shipment, :create?, policy_class: ShipmentExpensePolicy
      expenses = free_expenses.where(id: Array(params[:expense_ids])).includes(:supply_entry).to_a
      return redirect_to(new_sales_shipment_expense_path(@shipment), alert: t(".none")) if expenses.empty?

      # The receipt of each, when one was chosen (Fernando, 2026-11-16), to
      # who can edit that expense.
      receipts = params.fetch(:receipts, {})
      with_file = expenses.select { receipts[it.id.to_s].respond_to?(:read) }
      ActiveRecord::Associations::Preloader.new(records: with_file, associations: :receipt).call if with_file.any?
      expenses.each do |expense|
        file = receipts[expense.id.to_s]
        expense.receipt_upload = file if file.respond_to?(:read) && policy(expense).update?
        expense.shipment = @shipment
      end
      if (invalid = expenses.find(&:invalid?))
        return redirect_to(new_sales_shipment_expense_path(@shipment),
                           alert: t(".invalid", description: invalid.description, errors: invalid.errors.full_messages.to_sentence))
      end

      Expense.transaction { expenses.each(&:save!) }
      redirect_to sales_shipment_path(@shipment, anchor: "shipment-cost"), notice: t(".success", count: expenses.size)
    end

    def destroy
      authorize @shipment, :destroy?, policy_class: ShipmentExpensePolicy
      expense = @shipment.expenses.find(params[:id])
      expense.update!(shipment: nil)
      redirect_to sales_shipment_path(@shipment, anchor: "shipment-cost"), notice: t(".success"), status: :see_other
    end

    private
      def set_shipment
        @shipment = Shipment.find(params[:shipment_id])
      end

      # Expenses (not investments) on no shipment.
      def free_expenses = policy_scope(Expense).where(kind: "expense", shipment_id: nil)
      def eligible = free_expenses.includes(:receipt_info, :supply_entry)
  end
end
