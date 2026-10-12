import { Controller } from "@hotwired/stimulus"

// Timesheet grid (members × days). Attendance is a button per day that
// cycles — → 1 (full day) → ½ → —, with a hidden field holding what is
// sent; "Todos" fills a day for everyone and "Toda la semana" a member's
// whole period. Cans are typed. The totals of each member (days or cans,
// and pay) and of each day follow, and every change is announced
// ("timesheet:changed") for the save bar. Only a preview: the server saves
// and recalculates.
const NEXT = { "": "1", 1: "0.5", 0.5: "" }

export default class extends Controller {
  static targets = ["row", "rowTotal", "rowAmount", "dateTotal", "grandTotal", "dayValue"]
  static values = { labels: Object }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.number = new Intl.NumberFormat("es-HN", { maximumFractionDigits: 2 })
  }

  cycle(event) {
    const input = event.currentTarget.previousElementSibling
    this.set(input, NEXT[input.value] ?? "")
    this.update()
  }

  fillColumn(event) {
    this.cells(event.currentTarget.dataset.date).forEach((cell) => this.set(cell, "1"))
    this.update()
  }

  fillRow(event) {
    event.currentTarget.closest("tr").querySelectorAll("[data-date]").forEach((cell) => this.set(cell, "1"))
    this.update()
  }

  // A day's value and the look of its button.
  set(input, value) {
    if (input.disabled) return
    input.value = value
    const button = input.nextElementSibling
    if (button?.classList.contains("day-toggle")) {
      button.dataset.state = value
      button.textContent = this.labelsValue[value] ?? value
    }
  }

  update() {
    let grand = 0
    this.rowTargets.forEach((row, index) => {
      const total = [...row.querySelectorAll("[data-date]")].reduce((sum, cell) => sum + this.value(cell), 0)
      const rate = parseFloat(row.dataset.rate)
      const amount = Math.round(total * rate * 100) / 100
      this.rowTotalTargets[index].textContent = this.number.format(total)
      this.rowAmountTargets[index].textContent = rate > 0 ? `L ${this.money.format(amount)}` : "—"
      if (rate > 0) grand += amount
    })
    this.dateTotalTargets.forEach((cell) => {
      cell.textContent = this.number.format(this.cells(cell.dataset.date).reduce((sum, input) => sum + this.value(input), 0))
    })
    this.grandTotalTarget.textContent = `L ${this.money.format(grand)}`
    this.dispatch("changed")
  }

  cells(date) {
    return this.rowTargets.flatMap((row) => [...row.querySelectorAll(`[data-date='${date}']`)])
  }

  value(cell) {
    const parsed = parseFloat(cell.value)
    return parsed > 0 ? parsed : 0
  }
}
