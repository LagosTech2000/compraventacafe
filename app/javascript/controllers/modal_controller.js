import { Controller } from "@hotwired/stimulus"

// The app-wide modal: a <dialog> around the "modal" Turbo Frame. It opens
// when the frame loads a page and empties the frame when it closes.
//
// "Atrás" (data-modal-back, in the modal layout): each window remembers the
// pages it showed. In a drawer (the user's setting) links navigate the
// drawer itself, so back returns to the previous page; a window opened on top
// of another goes back by closing and showing the one below. Only pages
// fetched with GET count: a form sent and shown again is the same page.
export default class extends Controller {
  static targets = ["frame"]

  connect() {
    this.history = []
    this.frameTarget.addEventListener("turbo:before-fetch-request", this.rememberMethod)
    this.frameTarget.addEventListener("turbo:frame-render", this.record)
  }

  disconnect() {
    this.frameTarget.removeEventListener("turbo:before-fetch-request", this.rememberMethod)
    this.frameTarget.removeEventListener("turbo:frame-render", this.record)
  }

  open() {
    if (this.frameTarget.innerHTML.trim() !== "" && !this.element.open) this.element.showModal()
    this.updateBack()
  }

  close() {
    this.element.close()
  }

  back() {
    if (this.history.length > 1) {
      this.history.pop()
      this.goingBack = true
      this.frameTarget.src = this.history[this.history.length - 1]
    } else {
      this.close()
    }
  }

  // Runs on the dialog's "close" event, which can arrive after the closing
  // animation. If another modal was opened meanwhile, leave it alone.
  reset() {
    if (this.element.open || this.frameTarget.hasAttribute("busy")) return

    this.history = []
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

  // --- History ---------------------------------------------------------------

  rememberMethod = (event) => {
    this.lastMethod = (event.detail.fetchOptions?.method || "GET").toUpperCase()
  }

  record = (event) => {
    const url = event.detail.fetchResponse?.location?.href
    if (this.goingBack) {
      this.goingBack = false
    } else if (url && this.lastMethod === "GET" && this.history[this.history.length - 1] !== url) {
      this.history.push(url)
    }
  }

  // Back shows when there is a page to go back to, or a window below.
  updateBack() {
    const below = this.windowBelow()
    this.element.querySelectorAll("[data-modal-back]").forEach((button) => {
      button.hidden = !(this.history.length > 1 || below)
    })
  }

  windowBelow() {
    const windows = [...document.querySelectorAll("dialog[data-controller~='modal']")]
    return windows.slice(0, windows.indexOf(this.element)).some((dialog) => dialog.open)
  }
}
