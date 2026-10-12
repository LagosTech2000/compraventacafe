module ApplicationHelper
  def readable_module_keys
    return [] unless Current.user

    AppModule::KEYS.select { |key| Current.user.can?(key, :read) }
  end

  def module_root_path(key)
    public_send("#{key}_root_path")
  end

  # "Detalle" button that opens the record in the app-wide modal.
  def detail_button(path)
    modal_link_to t("shared.detail"), path, class: "btn btn-sm"
  end

  # Link that opens its page in the modal (forms, details). Inside a modal it
  # opens a second one on top.
  def modal_link_to(label, path, **options)
    link_to label, path, options.merge(data: { **options.fetch(:data, {}), turbo_frame: next_modal_frame })
  end

  # Link that leaves the modal and loads a full page.
  def page_link_to(label, path, **options)
    link_to label, path, options.merge(data: { **options.fetch(:data, {}), turbo_frame: "_top" })
  end

  # Forms sit on a card on full pages; inside the modal they already do.
  def form_surface_class(extra = "")
    # Wide screens: a form keeps a readable width unless it sets its own.
    width = "max-w-5xl" unless modal_request? || extra.include?("max-w-")
    [ (modal_request? ? nil : "panel p-5 sm:p-6"), width, extra ].compact_blank.join(" ")
  end

  # "Cancelar": closes the modal when inside it, otherwise goes back to `path`.
  def cancel_button(path, label: t("shared.cancel"))
    if modal_request?
      button_tag label, type: "button", class: "btn", data: { action: "modal#close" }
    else
      link_to label, path, class: "btn"
    end
  end

  # Active on its page and, unless exact, on the pages below it.
  # "EZ" for an avatar: the first letters of two names, or of the first two words.
  def initials(name, last_names = nil)
    words = last_names ? [ name.split.first, last_names.split.first ] : name.split.first(2)
    words.compact.map { |word| word[0] }.join.upcase
  end

  def nav_link_class(path, exact: false)
    active = current_page?(path) || (!exact && request.path.start_with?("#{path}/"))
    active ? "nav-pill nav-pill-active" : "nav-pill"
  end
end
