import { Controller } from "@hotwired/stimulus"

// A "?" button (HelpGuidesHelper). Copies its guide into the layout's help
// dialog and opens it. It is a separate <dialog> from the app-wide modal, so
// it opens on top of the modal and leaves the modal's page as it was.
export default class extends Controller {
  static targets = ["content"]

  open() {
    const dialog = document.getElementById("help-guide")
    if (!dialog) return

    const body = this.contentTarget.content.cloneNode(true)
    dialog.replaceChildren(body)
    dialog.setAttribute("aria-labelledby", dialog.querySelector("h2")?.id || "")
    dialog.showModal()
  }
}
