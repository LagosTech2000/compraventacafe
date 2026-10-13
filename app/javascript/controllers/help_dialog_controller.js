import { Controller } from "@hotwired/stimulus"

// The help dialog of the layout (see help_guide_controller.js). Closes with
// its × button, Escape (native) or a click on the backdrop.
export default class extends Controller {
  close() {
    this.element.close()
  }

  // Only a click that both starts and ends on the backdrop closes it
  // (selecting text and letting go outside does not).
  pressStart(event) {
    this.pressedOnBackdrop = event.target === this.element
  }

  closeOnBackdrop(event) {
    if (event.target === this.element && this.pressedOnBackdrop) this.close()
    this.pressedOnBackdrop = false
  }

  // Turbo keeps a snapshot of the page for the back button: never an open guide.
  closeBeforeCache() {
    if (this.element.open) this.close()
  }
}
