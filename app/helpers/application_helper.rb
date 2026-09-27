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

  # Link that opens its page in the modal (forms, details).
  def modal_link_to(label, path, **options)
    link_to label, path, options.merge(data: { **options.fetch(:data, {}), turbo_frame: ModalSupport::MODAL_FRAME })
  end

  # Link that leaves the modal and loads a full page.
  def page_link_to(label, path, **options)
    link_to label, path, options.merge(data: { **options.fetch(:data, {}), turbo_frame: "_top" })
  end

  # "Cancelar": closes the modal when inside it, otherwise goes back to `path`.
  def cancel_button(path, label: t("shared.cancel"))
    if modal_request?
      button_tag label, type: "button", class: "btn", data: { action: "modal#close" }
    else
      link_to label, path, class: "btn"
    end
  end

  def nav_link_class(path)
    base = "block rounded-2xl px-4 py-2 text-sm font-medium transition"
    if current_page?(path) || request.path.start_with?("#{path}/")
      "#{base} bg-primary text-on-primary"
    else
      "#{base} text-ink hover:bg-primary-soft"
    end
  end
end
