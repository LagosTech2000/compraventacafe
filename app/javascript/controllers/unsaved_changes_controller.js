import { Controller } from "@hotwired/stimulus"

// A form with changes not saved yet asks before they are lost (Fernando,
// 2026-10-18: the same in every work form, not only the timesheet): leaving
// the page, or closing the window it is in (modal_controller.js asks it,
// through data-dirty). Saving clears it. Changes come from the fields
// ("input", "change") or from controllers that announce them
// ("timesheet:changed"). A save bar (the timesheet) can say it too (status).
export default class extends Controller {
  static targets = ["status"]
  static values = { message: String, savedText: String, dirtyText: String }

  // data-dirty is the one truth: the window it is in clears it when it is
  // let go (modal_controller.js#mayLeave).
  get dirty() {
    return this.element.dataset.dirty === "true"
  }

  connect() {
    // The same page asked again is not leaving it (a save in the modal
    // refreshes the page behind, as it always did).
    this.beforeVisit = (event) => {
      if (event.detail.url === window.location.href) return
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
    this.element.dataset.dirty = "true"
    if (this.hasStatusTarget) this.statusTarget.textContent = this.dirtyTextValue
  }

  saving() {
    delete this.element.dataset.dirty
  }
}
