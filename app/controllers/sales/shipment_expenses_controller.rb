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
      expenses = eligible.where(id: Array(params[:expense_ids])).to_a
      return redirect_to(new_sales_shipment_expense_path(@shipment), alert: t(".none")) if expenses.empty?

      Expense.transaction { expenses.each { it.update!(shipment: @shipment) } }
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
      def eligible
        policy_scope(Expense).where(kind: "expense", shipment_id: nil)
      end
  end
end
