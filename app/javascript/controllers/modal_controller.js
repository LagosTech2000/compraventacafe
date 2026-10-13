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

  // Only a click that both starts and ends on the backdrop closes it:
  // selecting text in a field and letting go outside keeps the form.
  pressStart(event) {
    this.pressedOnBackdrop = event.target === this.element
  }

  closeOnBackdrop(event) {
    if (event.target === this.element && this.pressedOnBackdrop) this.close()
    this.pressedOnBackdrop = false
  }

  // The response had no modal frame (e.g. the session expired and the server
  // sent the sign-in page): show it as a full page instead of an error.
  fallback(event) {
    event.preventDefault()
    event.detail.visit(event.detail.response)
  }
}
