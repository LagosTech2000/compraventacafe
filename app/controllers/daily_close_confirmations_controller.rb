# «Confirmar cierre» of a daily close (Fernando, 2026-11-23).
class DailyCloseConfirmationsController < ApplicationController
  def create
    confirmation = DailyCloseConfirmation.new(module_key: params[:module_key], day: params[:day], confirmed_by: Current.user)
    authorize confirmation
    if confirmation.save
      redirect_back_or_to root_path, notice: t(".success")
    else
      redirect_back_or_to root_path, alert: confirmation.errors.full_messages.to_sentence
    end
  end

  def destroy
    confirmation = authorize DailyCloseConfirmation.find(params[:id])
    confirmation.destroy!
    redirect_back_or_to root_path, notice: t(".success")
  end
end
