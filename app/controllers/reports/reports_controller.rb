require "csv"

module Reports
  # Every report on one screen: the report is picked from a list (or a
  # suggested one, or a saved filter), and its filters, figures, charts and
  # table follow. The table loads page by page as it scrolls (turbo stream);
  # the charts load in their own frame so the table shows first.
  class ReportsController < ApplicationController
    before_action :set_report
    # The CSV reads every filtered row (up to 50,000); the charts run several
    # grouped queries each time the filters change.
    rate_limit_per_user name: "report_csv", to: 10, within: 1.minute, only: :show, if: -> { request.format.csv? }
    rate_limit_per_user name: "report_charts", to: 60, within: 1.minute, only: :charts

    def show
      if @report.nil?
        authorize [ :reports, :home ], :index?
        return render :empty
      end

      authorize @report
      respond_to do |format|
        format.html { @rows, @more = @report.page }
        format.turbo_stream { @rows, @more = @report.page }
        format.csv { send_data csv, filename: csv_filename, type: "text/csv; charset=utf-8" }
      end
    end

    def charts
      authorize @report
      render layout: false
    end

    private
      # The report asked for, or the first one the user may see.
      def set_report
        report_class = params[:id] ? Report.find(params[:id]) : Report.catalog.find { |report| policy(report).show? }
        raise ActiveRecord::RecordNotFound if params[:id] && report_class.nil?

        @report = report_class&.new(params, user: Current.user)
      end

      # With a byte order mark, so Excel reads the accents.
      def csv
        columns = @report.table_columns
        "﻿" + CSV.generate do |rows|
          rows << columns.map { |column| @report.column_label(column) }
          @report.each_row { |row| rows << columns.map { |column| helpers.report_csv_value(column, row) } }
        end
      end

      def csv_filename
        "#{t("reports.csv_prefix")}-#{@report.title.parameterize}-#{Time.zone.today.iso8601}.csv"
      end
  end
end
