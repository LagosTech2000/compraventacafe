module Reports
  # Each user's saved report filters ("Mis filtros"): saved from a report
  # with a name, listed and removed in a modal.
  class SavedReportsController < ApplicationController
    def index
      authorize SavedReport
      @saved_reports = policy_scope(SavedReport).ordered
    end

    def new
      @saved_report = SavedReport.new(user: Current.user, report_key: params[:report_key],
                                      params: params[:filters]&.to_unsafe_h || {})
      authorize @saved_report
    end

    def create
      @saved_report = SavedReport.new(saved_report_params.merge(user: Current.user))
      authorize @saved_report

      if @saved_report.save
        close_modal_with notice: t(".success", name: @saved_report.name), fallback: report_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      @saved_report = policy_scope(SavedReport).find(params[:id])
      authorize @saved_report
      @saved_report.destroy!
      redirect_to reports_saved_reports_path, notice: t(".success", name: @saved_report.name)
    end

    private
      def saved_report_params
        params.expect(saved_report: [ :name, :report_key, params: {} ])
      end

      def report_path
        reports_report_path(@saved_report.report_key, @saved_report.params)
      end
  end
end
