import { Controller } from "@hotwired/stimulus"

// Editing an expense or an investment, its kind can change (Fernando,
// 2026-11-12): each kind has its own categories, so only the list of the
// kind chosen shows and is sent.
export default class extends Controller {
  static targets = ["kind", "panel"]

  connect() {
    this.update()
  }

  update() {
    // Registering, the kind is the screen's: nothing to switch.
    if (!this.hasKindTarget) return

    const kind = this.kindTargets.find((radio) => radio.checked)?.value
    this.panelTargets.forEach((panel) => {
      const shown = panel.dataset.kind === kind
      panel.hidden = !shown
      panel.querySelectorAll("select").forEach((select) => { select.disabled = !shown })
    })
  }
}
