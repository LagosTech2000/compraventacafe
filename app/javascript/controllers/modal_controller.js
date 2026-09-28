import { Controller } from "@hotwired/stimulus"

// The app-wide modal: a <dialog> around the "modal" Turbo Frame. It opens
// when the frame loads a page and empties the frame when it closes.
export default class extends Controller {
  static targets = ["frame"]

  open() {
    if (this.frameTarget.innerHTML.trim() !== "" && !this.element.open) this.element.showModal()
  }

  close() {
    this.element.close()
  }

  // Runs on the dialog's "close" event, which can arrive after the closing
  // animation. If another modal was opened meanwhile, leave it alone.
  reset() {
    if (this.element.open || this.frameTarget.hasAttribute("busy")) return

    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = ""
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }

  // The response had no modal frame (e.g. the session expired and the server
  // sent the sign-in page): show it as a full page instead of an error.
  fallback(event) {
    event.preventDefault()
    event.detail.visit(event.detail.response)
  }
}
