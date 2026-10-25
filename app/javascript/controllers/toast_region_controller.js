import { Controller } from "@hotwired/stimulus"

// Keeps the toasts above everything, modals and the help guide included,
// and usable there. Those dialogs open in the browser's top layer, where
// z-index does not reach, and make the rest of the page inert (a toast left
// outside could not be closed). So the toasts are a popover (top layer)
// that lives inside the dialog on top while one is open, and in the page
// otherwise (#toasts). Dialogs stack in page order (modal, modal_2, modal_3, then the
// help guide), so the last open one is on top. The region goes away with
// its last toast.
export default class extends Controller {
  connect() {
    if (!this.element.showPopover) return // older browsers: a fixed layer with z-index

    this.observer = new MutationObserver((mutations) => {
      const dialogChanged = mutations.some((mutation) => mutation.type === "attributes" && mutation.target.matches("dialog"))
      this.place(dialogChanged)
    })
    this.observer.observe(document.body, { attributes: true, attributeFilter: ["open"], subtree: true, childList: true })
    this.place(true)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  place(raise) {
    if (!this.element.querySelector(".toast")) return this.element.remove()

    // Without a window open, its place in the page (#toasts, see the layout).
    const host = [ ...document.querySelectorAll("dialog[open]") ].filter((dialog) => dialog.matches(":modal")).pop() ||
      document.getElementById("toasts") || document.body
    // Moving it reconnects this controller, which places and raises it again.
    if (this.element.parentElement !== host) return host.append(this.element)
    if (raise) this.raise()
  }

  // Last shown is on top of the top layer.
  raise() {
    if (this.element.matches(":popover-open")) this.element.hidePopover()
    this.element.showPopover()
  }
}
