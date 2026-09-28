import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Closes the modal after a save. Announces the new record with a window
// event (a picker field listens for it) or refreshes the page behind.
export default class extends Controller {
  static values = { event: String, detail: Object, refresh: Boolean }

  connect() {
    if (this.eventValue) window.dispatchEvent(new CustomEvent(this.eventValue, { detail: this.detailValue }))
    this.element.closest("dialog")?.close()
    if (this.refreshValue) Turbo.visit(window.location.href, { action: "replace" })
  }
}
