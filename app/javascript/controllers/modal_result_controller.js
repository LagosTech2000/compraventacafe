import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Closes the modal after a save. Announces the new record with a window
// event (a picker field listens for it) or refreshes the page behind (or
// goes to the "visit" URL, e.g. the loan with the new payment's receipt open).
export default class extends Controller {
  static values = { event: String, detail: Object, refresh: Boolean, visit: String }

  connect() {
    if (this.eventValue) window.dispatchEvent(new CustomEvent(this.eventValue, { detail: this.detailValue }))
    this.element.closest("dialog")?.close()
    if (this.refreshValue) Turbo.visit(this.visitValue || window.location.href, { action: "replace" })
  }
}
