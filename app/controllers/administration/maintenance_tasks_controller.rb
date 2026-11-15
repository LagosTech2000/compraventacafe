module Administration
  # Mantenimiento de datos (Fernando, 2026-11-15): the data maintenance
  # tasks, what each does and how it leaves the system, its options and its
  # last runs. Only User::DATA_EXPORTER_ID (MaintenancePolicy).
  class MaintenanceTasksController < ApplicationController
    def index
      authorize :maintenance
      @tasks = Maintenance.tasks
      @last_runs = MaintenanceRun.where(task_key: @tasks.map(&:key)).newest_first.group_by(&:task_key).transform_values(&:first)
      @runs = MaintenanceRun.includes(:user).newest_first.limit(15)
    end

    def show
      authorize :maintenance
      @task = Maintenance.find_by_slug(params[:slug]) or raise ActiveRecord::RecordNotFound
      @runs = MaintenanceRun.includes(:user).where(task_key: @task.key).newest_first.limit(20)
      @categories = FinanceCategory.where(kind: "expense").includes(:parent).sort_by(&:full_name) if @task.params_spec.any? { it[:type] == :ids }
    end
  end
end
