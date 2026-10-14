# The "modal" Turbo Frame, reusable across the app.
#
# Any link with data-turbo-frame="modal" loads its page inside the dialog of
# the main layout; the page renders with the "modal" layout. After a form in
# the modal saves, #close_modal_with closes it and either tells the page what
# was created (picker: the parent form adds the new option) or refreshes it.
#
# Modals stack: a modal link inside a modal opens the next frame (modal_2,
# modal_3), in a dialog on top of it, so a form opened from a modal (a new
# zone from the new-producer form) keeps the one below intact.
module ModalSupport
  extend ActiveSupport::Concern

  MODAL_FRAMES = %w[modal modal_2 modal_3].freeze
  MODAL_FRAME = MODAL_FRAMES.first

  included do
    # A request for another Turbo Frame (a report's results) only needs the
    # frame: no navigation or dialogs around it.
    layout -> { modal_request? ? "modal" : (turbo_frame_request? ? "turbo_rails/frame" : "application") }
    helper_method :modal_request?, :picker_request?, :modal_frame_id, :next_modal_frame, :modal_frame_for
  end

  private
    def modal_request?
      MODAL_FRAMES.include?(turbo_frame_request_id)
    end

    # The modal frame this request renders into.
    def modal_frame_id
      turbo_frame_request_id if modal_request?
    end

    # Where a modal link on this page opens: the first modal from a page,
    # the one above from inside a modal (the top one replaces itself).
    def next_modal_frame
      return MODAL_FRAME unless modal_request?

      MODAL_FRAMES[MODAL_FRAMES.index(modal_frame_id) + 1] || MODAL_FRAMES.last
    end

    # Where a modal link to `path` opens. In a drawer (the user's setting) a
    # page navigates inside the drawer it is in, with its history; a picker
    # (?picker=1) still opens on top, so the form below keeps what is typed.
    def modal_frame_for(path)
      return next_modal_frame unless modal_request? && Current.user&.drawer?

      picker = Rack::Utils.parse_query(URI.parse(path.to_s).query.to_s)["picker"] == "1"
      picker ? next_modal_frame : modal_frame_id
    rescue URI::InvalidURIError
      next_modal_frame
    end

    # The modal was opened from a form field to create an option for it.
    def picker_request?
      params[:picker] == "1"
    end

    # Saves from a modal close it. A picker receives the new record through a
    # browser event; any other page refreshes and shows the notice (or goes
    # to `visit`, when given).
    def close_modal_with(notice:, event: nil, detail: {}, fallback:, visit: nil)
      unless modal_request?
        redirect_to fallback, notice: notice
        return
      end

      flash[:notice] = notice unless picker_request?
      render "shared/modal_result", layout: false, locals: { event:, detail:, refresh: !picker_request?, visit: }
    end
end
