module ApplicationHelper
  def readable_module_keys
    return [] unless Current.user

    AppModule::KEYS.select { |key| Current.user.can?(key, :read) }
  end

  def module_root_path(key)
    public_send("#{key}_root_path")
  end

  # "Detalle" button that opens the record in the app-wide modal.
  # Also opened by a click anywhere on its row (row_link_controller.js).
  def detail_button(path)
    modal_link_to t("shared.detail"), path, class: "btn btn-sm", data: { row_link: true }
  end

  # Link that opens its page in the modal (forms, details). Inside a modal it
  # opens a second one on top; inside a drawer it navigates the drawer itself
  # (its "Atrás" goes back), except a picker, which stacks to keep the form
  # below it. Takes a block for the link's content, like link_to.
  # A work form that asks before its changes are lost (unsaved_changes_controller.js):
  # its fields mark it changed and sending it clears it.
  def unsaved_changes_actions
    "input->unsaved-changes#changed change->unsaved-changes#changed submit->unsaved-changes#saving"
  end

  def modal_link_to(*args, **options, &block)
    path = block ? args.first : args.second
    link_to(*args, **options.merge(data: { **options.fetch(:data, {}), turbo_frame: modal_frame_for(path) }), &block)
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

  # The initials of a person (first name + last name) or a user.
  def initials_for(record)
    record.is_a?(Person) ? initials(record.first_names.to_s, record.last_names.to_s.presence) : initials(record.name.to_s)
  end

  # A round profile photo (HasPhoto), or the initials when there is none.
  # Decorative: the name beside it carries the meaning.
  def avatar(record, css: "size-8 text-xs")
    if (photo = record.photo_info)
      image_tag profile_photo_path(photo, v: photo.version), alt: "", class: "#{css} shrink-0 rounded-full object-cover", loading: "lazy"
    else
      tag.span initials_for(record), class: "#{css} grid shrink-0 place-items-center rounded-full bg-primary-soft font-bold text-primary", aria: { hidden: true }
    end
  end

  # A name in a list with the person's photo or initials before it (Fernando,
  # 2026-10-18: the same as in the details). The initials are drawn by CSS
  # (.avatar-initials), so the cell's text is only the name.
  def with_avatar(person, name = person.full_name)
    picture = if (photo = person.photo_info)
      image_tag profile_photo_path(photo, v: photo.version), alt: "", class: "size-7 shrink-0 rounded-full object-cover", loading: "lazy"
    else
      tag.span class: "avatar-initials size-7 text-[0.6rem]", data: { initials: initials_for(person) }, aria: { hidden: true }
    end
    tag.span(class: "flex min-w-0 items-center gap-2") { picture + tag.span(name, class: "min-w-0 truncate") }
  end

  # A panel of shared/_tabs: hidden unless it is the one shown first.
  def tab_panel(group, key, selected: false, &)
    tag.section(id: "#{group}-#{key}", role: "tabpanel", aria: { labelledby: "#{group}-tab-#{key}" },
                hidden: !selected, class: "mt-4", data: { tabs_target: "panel" }, &)
  end

  # The left navigation is collapsed to its icons (SidebarState).
  def sidebar_collapsed? = SidebarState.collapsed?(cookies)

  def nav_link_class(path, exact: false)
    active = current_page?(path) || (!exact && request.path.start_with?("#{path}/"))
    active ? "nav-pill nav-pill-active" : "nav-pill"
  end
end
