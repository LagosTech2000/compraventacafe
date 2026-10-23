# The matches of a searchable picker, as JSON (PickerSearch): the producer of
# a purchase, the person of a loan, the employee of a payroll...
class PickerSearchesController < ApplicationController
  def show
    raise ActiveRecord::RecordNotFound unless PickerSearch.kind?(params[:kind])

    authorize :picker_search, :"#{params[:kind]}?"
    render json: PickerSearch.new(params[:kind], params[:q], except: params[:except])
  end
end
