import { Controller } from "@hotwired/stimulus"

// The invoices chosen for a lot, each with the percent it takes (Fernando,
// 2026-11-13): shows the gross and net pounds each percent comes to and all of them against
// the lot's room, and keeps «Agregar» off while none is marked or they
// pass the room. The server checks it again.
//
// Choosing many at once (Fernando, 2026-11-15: «bulk select»): the header box
// marks or unmarks every invoice loaded; Shift + clic marks a range;
// «Llenar el lote» marks them in the list's order until the lot is full,
// the last one with the part that fits.
export default class extends Controller {
  static targets = ["row", "summary", "submit", "all"]
  static values = { room: Number, texts: Object }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  // Rows that «Cargar más» brings in.
  rowTargetConnected() {
    if (this.pounds) this.update()
  }

  toggleAll() {
    const on = this.allTarget.checked
    this.rowTargets.forEach((row) => { this.box(row).checked = on })
    this.update()
  }

  // Shift + clic: every box between the last one clicked and this one takes its state.
  pick(event) {
    const rows = this.rowTargets
    const index = rows.indexOf(event.target.closest("tr"))
    if (event.shiftKey && this.lastIndex !== undefined && index >= 0) {
      const [from, to] = [Math.min(this.lastIndex, index), Math.max(this.lastIndex, index)]
      rows.slice(from, to + 1).forEach((row) => { this.box(row).checked = event.target.checked })
    }
    this.lastIndex = index
    this.update()
  }

  fill() {
    let room = this.roomValue
    this.rowTargets.forEach((row) => {
      const input = this.percent(row)
      const left = parseFloat(input.max)
      const gross = parseFloat(row.dataset.gross)
      if (room <= 0.005 || !(gross > 0) || !(left > 0)) {
        this.box(row).checked = false
        return
      }
      const percent = Math.min(left, Math.floor(room / gross * 100 * 10000) / 10000)
      if (percent <= 0) {
        this.box(row).checked = false
        return
      }
      input.value = String(percent)
      this.box(row).checked = true
      room -= Math.round(gross * percent) / 100
    })
    this.update()
  }

  update() {
    let chosen = 0
    let total = 0
    this.rowTargets.forEach((row) => {
      const box = this.box(row)
      const percent = parseFloat(this.percent(row).value)
      const takes = percent > 0 ? Math.round(parseFloat(row.dataset.gross) * percent) / 100 : 0
      const takesNet = percent > 0 ? Math.round(parseFloat(row.dataset.net) * percent) / 100 : 0
      // What the percent comes to, marked or not; dimmed until it is marked.
      row.querySelector("[data-takes-gross]").textContent = takes > 0 ? this.textsValue.gross.replace("%{pounds}", this.pounds.format(takes)) : "—"
      row.querySelector("[data-takes-net]").textContent = takes > 0 ? this.textsValue.net.replace("%{pounds}", this.pounds.format(takesNet)) : ""
      row.querySelector("[data-takes]").classList.toggle("opacity-50", !box.checked)
      if (box.checked) {
        chosen += 1
        total += takes
      }
    })
    const over = total > this.roomValue + 0.005
    const text = (over ? this.textsValue.over : this.textsValue.chosen)
      .replace("%{count}", chosen).replace("%{pounds}", this.pounds.format(total)).replace("%{room}", this.pounds.format(this.roomValue))
    this.summaryTarget.textContent = text
    this.summaryTarget.classList.toggle("text-danger", over)
    this.submitTarget.disabled = chosen === 0 || over
    if (this.hasAllTarget) {
      this.allTarget.checked = chosen > 0 && chosen === this.rowTargets.length
      this.allTarget.indeterminate = chosen > 0 && chosen < this.rowTargets.length
    }
  }

  box(row) { return row.querySelector("input[type=checkbox]") }
  percent(row) { return row.querySelector("input[name$='[percent]']") }
}
