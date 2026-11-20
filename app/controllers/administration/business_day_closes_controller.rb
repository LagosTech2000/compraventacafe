module Administration
  # «Cierre del día» (Fernando, 2026-11-18): the checklist of a day
  # (DailyCheck) and «Cerrar el día», after which nothing dated that day or
  # before changes (DayLock); the closes made, and «Reabrir» the latest one
  # (only the main user, with a reason).
  class BusinessDayClosesController < ApplicationController
    def index
      authorize BusinessDayClose
      @close = BusinessDayClose.new(closed_on: chosen_day)
      load_page
    end

    def create
      authorize BusinessDayClose
      @close = BusinessDayClose.new(params.expect(business_day_close: %i[ closed_on notes ]).merge(closed_by: Current.user))
      check = DailyCheck.new(day: @close.closed_on || Time.zone.today)
      if !check.ok? && params[:reviewed] != "1"
        @close.errors.add(:base, :review_first)
      elsif @close.save
        return redirect_to administration_day_closes_path, notice: t(".success", date: l(@close.closed_on))
      end
      load_page
      render :index, status: :unprocessable_content
    end

    def reopen
      close = BusinessDayClose.find(params[:id])
      authorize close
      close.reopen!(user: Current.user, reason: params.dig(:business_day_close, :reopen_reason))
      redirect_to administration_day_closes_path, notice: t(".success", date: l(close.closed_on))
    rescue ActiveRecord::RecordInvalid
      redirect_to administration_day_closes_path, alert: close.errors.full_messages.to_sentence
    end

    private
      # The day asked, or the one after the last closed (today at most).
      def chosen_day
        asked = Date.parse(params[:day].to_s) rescue nil
        through = BusinessDayClose.locked_through
        [ asked || (through ? through + 1 : Time.zone.today), Time.zone.today ].min
      end

      def load_page
        @check = DailyCheck.new(day: @close.closed_on || Time.zone.today)
        @closes = BusinessDayClose.includes(:closed_by, :reopened_by).newest_first.limit(60)
        @locked_through = BusinessDayClose.locked_through
      end
  end
end
