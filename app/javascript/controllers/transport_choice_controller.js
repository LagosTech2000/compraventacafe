import { Controller } from "@hotwired/stimulus"

// «Nueva salida»: a carrier (with its trip price) or a driver, one or the
// other (client, 2026-10-30). Shows the fields of the one chosen and turns
// off the other's, so they are not sent; the server clears them too.
export default class extends Controller {
  static targets = ["mode", "panel"]

  update() {
    const mode = this.modeTargets.find((radio) => radio.checked)?.value
    this.panelTargets.forEach((panel) => {
      const shown = panel.dataset.mode === mode
      panel.hidden = !shown
      panel.querySelectorAll("input, select, textarea").forEach((field) => { field.disabled = !shown })
    })
  }
}
