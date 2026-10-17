module Farms
  # Tasks of a payroll paid by task ("por obra").
  class TasksController < ApplicationController
    include FarmsPayrollScoped
    before_action :set_task, only: %i[ edit update destroy ]

    def new
      raise ActiveRecord::RecordNotFound unless @payroll.task?

      @task = authorize @payroll.tasks.build
    end

    def create
      @task = authorize @payroll.tasks.build(task_params)

      if save_task
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("tasks")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      @task.assign_attributes(task_params)
      if save_task
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("tasks")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @task.destroy!
      close_modal_with notice: t(".success"), fallback: payroll_tab_path("tasks")
    end

    private
      def set_task
        @task = authorize @payroll.tasks.find(params[:id])
      end

      def task_params
        params.expect(payroll_task: [ :name, :pricing, :amount, :quantity, :quantity_unit, :unit_price, :barrel_liters,
                                      :completed_on, :observations, member_ids: [] ])
      end

      # A task by manzana needs the farm's extension: when the farm has
      # none, the form asks for it and it is saved with the task, all or
      # nothing (with the farm's own permission).
      def save_task
        farm = @payroll.farm
        area = params.fetch(:farm, {}).permit(:area_value, :area_unit)
        return @task.save unless @task.per_manzana? && farm.area_value_in_database.nil? && area[:area_value].present?

        authorize farm, :update?
        saved = Farm.transaction { (farm.update(area) && @task.save) || raise(ActiveRecord::Rollback) }
        return true if saved

        farm.errors.full_messages.each { |message| @task.errors.add(:base, message) }
        farm.reload.assign_attributes(area) # the form shows what was typed
        false
      end
  end
end
