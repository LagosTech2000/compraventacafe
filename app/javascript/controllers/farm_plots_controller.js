import { Controller } from "@hotwired/stimulus"

// The plot of a purchase (Fernando, 2026-11-15): only the plots of the farm
// chosen, which its option brings (data-plots: [[id, name], …]). Without a
// farm, or a farm without plots, the field hides. Changing the farm keeps
// the plot only if it is of the new one.
export default class extends Controller {
  static targets = ["farm", "plot", "field"]

  connect() {
    this.blank = this.plotTarget.options[0]?.text || ""
    this.refresh()
  }

  refresh() {
    const option = this.farmTarget.selectedOptions[0]
    let plots = []
    try { plots = JSON.parse(option?.dataset.plots || "[]") } catch { plots = [] }
    const chosen = this.plotTarget.value
    this.plotTarget.replaceChildren(new Option(this.blank, ""), ...plots.map(([ id, name ]) => new Option(name, id)))
    if (plots.some(([ id ]) => String(id) === chosen)) this.plotTarget.value = chosen
    this.fieldTarget.hidden = plots.length === 0
  }
}
