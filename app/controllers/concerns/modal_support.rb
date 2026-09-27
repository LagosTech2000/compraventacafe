# The "modal" Turbo Frame, reusable across the app.
#
# Any link with data-turbo-frame="modal" loads its page inside the dialog of
# the main layout; the page renders with the "modal" layout. After a form in
# the modal saves, #close_modal_with closes it and either tells the page what
# was created (picker: the parent form adds the new option) or refreshes it.
module ModalSupport
  extend ActiveSupport::Concern

  MODAL_FRAME = "modal".freeze

  included do
    layout -> { modal_request? ? "modal" : "application" }
    helper_method :modal_request?, :picker_request?
  end

  private
    def modal_request?
      turbo_frame_request_id == MODAL_FRAME
    end

    # The modal was opened from a form field to create an option for it.
    def picker_request?
      params[:picker] == "1"
    end

    # Saves from a modal close it. A picker receives the new record through a
    # browser event; any other page refreshes and shows the notice.
    def close_modal_with(notice:, event: nil, detail: {}, fallback:)
      unless modal_request?
        redirect_to fallback, notice: notice
        return
      end

      flash[:notice] = notice unless picker_request?
      render "shared/modal_result", locals: { event:, detail:, refresh: !picker_request? }
    end
end
