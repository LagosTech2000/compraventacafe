import { Controller } from "@hotwired/stimulus"

// A click anywhere on a list row (table row, card, or an element marked
// data-row-link-scope) opens it like its "Detalle"/"Abrir" button, the link
// marked data-row-link. The button stays for the keyboard and screen
// readers. Clicks on the row's own controls (links, buttons, fields) and
// text being selected are left alone; Ctrl/⌘ opens it in a new tab.
// On <body>, for every list of the app (pages and modals).
const ROW = "[data-row-link-scope], tr, .data-card, li"
const CONTROLS = "a, button, input, select, textarea, label, summary, [contenteditable], [data-row-link-ignore]"

export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.open)
  }

  disconnect() {
    this.element.removeEventListener("click", this.open)
  }

  open = (event) => {
    if (event.defaultPrevented || event.button !== 0 || event.target.closest(CONTROLS)) return

    const row = event.target.closest(ROW)
    const link = row?.querySelector("[data-row-link]")
    if (!link || this.selectingText(row)) return

    if (event.ctrlKey || event.metaKey) window.open(link.href, "_blank", "noopener")
    else link.click()
  }

  selectingText(row) {
    const selection = window.getSelection()
    return selection && !selection.isCollapsed && row.contains(selection.anchorNode)
  }
}
