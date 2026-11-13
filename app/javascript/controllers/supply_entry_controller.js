import { Controller } from "@hotwired/stimulus"

// An entry of supplies with several lines (Fernando, 2026-11-13): adds and
// removes lines from a <template>, and shows the total (the investment).
// A supply created in the modal ("supply:created") joins every line's list
// and is chosen in the last empty line. The server sums it again.
export default class extends Controller {
  static targets = ["lines", "line", "template", "empty", "supply", "amount", "destroy", "total"]

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    if (this.visibleLines().length === 0) this.add()
    this.update()
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, String(Date.now()))
    this.linesTarget.insertAdjacentHTML("beforeend", html)
    this.update()
    return this.lineTargets[this.lineTargets.length - 1]
  }

  addAndFocus() {
    this.add().querySelector("select")?.focus()
  }

  remove(event) {
    event.target.closest("[data-supply-entry-target~='line']").remove()
    this.update()
  }

  addSupply({ detail: { id, name, unit } }) {
    const label = `${name} (${unit})`
    const selects = [...this.supplyTargets, this.templateTarget.content.querySelector("select")]
    selects.forEach((select) => select.add(new Option(label, String(id))))
    const line = this.visibleLines().find((item) => item.querySelector("select").value === "") || this.add()
    line.querySelector("select").value = String(id)
    line.querySelector("input[type=number]")?.focus()
  }

  update() {
    const lines = this.visibleLines()
    const total = lines.reduce((sum, line) => {
      const amount = parseFloat(line.querySelector("[data-supply-entry-target~='amount']").value)
      return sum + (amount > 0 ? amount : 0)
    }, 0)
    this.emptyTarget.hidden = lines.length > 0
    this.totalTarget.textContent = `L ${this.money.format(Math.round(total * 100) / 100)}`
  }

  visibleLines() {
    return this.lineTargets.filter((line) => !line.hidden)
  }
}
