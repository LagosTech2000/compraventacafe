import { Controller } from "@hotwired/stimulus"

// A form edited in place (the timesheet): its save bar says when there are
// changes not saved yet, and leaving the page then asks first. Saving
// clears it. Changes come from the fields ("input") or from controllers that
// announce them ("timesheet:changed").
export default class extends Controller {
  static targets = ["status"]
  static values = { message: String, savedText: String, dirtyText: String }

  connect() {
    this.dirty = false
    this.beforeVisit = (event) => {
      if (this.dirty && !window.confirm(this.messageValue)) event.preventDefault()
    }
    this.beforeUnload = (event) => {
      if (!this.dirty) return
      event.preventDefault()
      event.returnValue = ""
    }
    document.addEventListener("turbo:before-visit", this.beforeVisit)
    window.addEventListener("beforeunload", this.beforeUnload)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
    window.removeEventListener("beforeunload", this.beforeUnload)
  }

  changed() {
    this.dirty = true
    this.element.dataset.dirty = "true"
    if (this.hasStatusTarget) this.statusTarget.textContent = this.dirtyTextValue
  }

  saving() {
    this.dirty = false
  }
}
