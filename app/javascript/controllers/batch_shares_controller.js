import { Controller } from "@hotwired/stimulus"

// The invoices chosen for a lot, each with the percent it takes (Fernando,
// 2026-11-13): shows the gross and net pounds each percent comes to and all of them against
// the lot's room, and keeps «Agregar» off while none is marked or they
// pass the room. The server checks it again.
export default class extends Controller {
  static targets = ["row", "summary", "submit"]
  static values = { room: Number, texts: Object }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    let chosen = 0
    let total = 0
    this.rowTargets.forEach((row) => {
      const box = row.querySelector("input[type=checkbox]")
      const percent = parseFloat(row.querySelector("input[type=number]").value)
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
  }
}
