# The "?" button and the help dialog (see HelpGuide). The dialog is its own
# <dialog>, apart from the app-wide modal: it slides in from the side and
# opens on top of the modal without replacing what the modal shows.
module HelpGuidesHelper
  def current_help_guide
    HelpGuide.for_screen(controller_path, action_name)
  end

  # Round "?" button that opens `guide`. With `label: true` it also shows
  # text, for process guides placed inside a page.
  def help_guide_button(guide = current_help_guide, label: false)
    tag.div(class: "contents", data: { controller: "help-guide" }) do
      button = tag.button(type: "button", title: t("help_guides.ui.open", title: guide.title),
                          aria: { label: t("help_guides.ui.open", title: guide.title), haspopup: "dialog" },
                          class: label ? "btn btn-sm" : "help-button",
                          data: { action: "help-guide#open" }) do
        safe_join([ icon(:help, css: label ? "size-4" : "size-5"), (tag.span(t("help_guides.ui.how_it_works")) if label) ])
      end
      button + tag.template(render("shared/help_guide", guide:), data: { help_guide_target: "content" })
    end
  end
end
