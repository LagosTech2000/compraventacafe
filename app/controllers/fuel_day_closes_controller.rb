# The day's fuel close (Fernando, 2026-11-23): one per day, from either daily close.
class FuelDayClosesController < ApplicationController
  def create
    close = FuelDayClose.new(day: params[:day], closed_by: Current.user)
    authorize close
    if close.save
      redirect_back_or_to root_path, notice: t(".success")
    else
      redirect_back_or_to root_path, alert: close.errors.full_messages.to_sentence
    end
  end

  def destroy
    close = authorize FuelDayClose.find(params[:id])
    close.destroy!
    redirect_back_or_to root_path, notice: t(".success")
  end
end
