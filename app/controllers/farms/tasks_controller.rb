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

      if @task.save
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("tasks")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @task.update(task_params)
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
        params.expect(payroll_task: [ :name, :amount, :completed_on, :observations, member_ids: [] ])
      end
  end
end
