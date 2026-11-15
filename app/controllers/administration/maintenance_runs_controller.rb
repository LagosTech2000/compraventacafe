module Administration
  # Runs a data maintenance task (Maintenance::Runner): a check or a
  # preview from its page; applying only from a preview (the same options)
  # and after saying the backup was downloaded; undoing an applied run.
  class MaintenanceRunsController < ApplicationController
    rate_limit_per_user name: "maintenance", to: 20, within: 10.minutes, only: %i[create revert]

    def create
      authorize :maintenance
      if params[:from_run_id].present?
        apply_preview
      else
        task = Maintenance.find_by_slug(params[:slug]) or raise ActiveRecord::RecordNotFound
        run = Maintenance::Runner.run(task, params: params.fetch(:task_params, {}).permit(:from, :to, :days, category_ids: []).to_h, user: Current.user)
        redirect_to administration_maintenance_run_path(run)
      end
    end

    def show
      authorize :maintenance
      @run = MaintenanceRun.includes(:user).find(params[:id])
      @task = @run.task
    end

    def revert
      authorize :maintenance
      run = MaintenanceRun.find(params[:id])
      return redirect_to(administration_maintenance_run_path(run), alert: t(".not_revertible")) unless run.revertible?

      revert = Maintenance::Runner.revert(run, user: Current.user)
      redirect_to administration_maintenance_run_path(revert), notice: (revert.failed? ? nil : t(".success"))
    end

    private
      def apply_preview
        preview = MaintenanceRun.find(params[:from_run_id])
        return redirect_to(administration_maintenance_run_path(preview), alert: t(".not_appliable")) unless preview.appliable?
        return redirect_to(administration_maintenance_run_path(preview), alert: t(".backup_first")) unless params[:backup_confirmed] == "1"

        run = Maintenance::Runner.run(preview.task, params: preview.params, apply: true, user: Current.user)
        redirect_to administration_maintenance_run_path(run), notice: (run.failed? ? nil : t(".applied"))
      end
  end
end
