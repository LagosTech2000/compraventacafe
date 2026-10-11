import { Controller } from "@hotwired/stimulus"

// Timesheet grid (members × days): "Todos" fills a day with a full day for
// everyone, and the totals of each member (days or cans, and pay) and of
// each day follow what is typed. Only a preview: the server saves and
// recalculates.
export default class extends Controller {
  static targets = ["row", "rowTotal", "rowAmount", "dateTotal", "grandTotal"]

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.number = new Intl.NumberFormat("es-HN", { maximumFractionDigits: 2 })
  }

  fillColumn(event) {
    this.cells(event.currentTarget.dataset.date).forEach((cell) => { if (!cell.disabled) cell.value = "1" })
    this.update()
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
  }

  cells(date) {
    return this.rowTargets.flatMap((row) => [...row.querySelectorAll(`[data-date='${date}']`)])
  }

  value(cell) {
    const parsed = parseFloat(cell.value)
    return parsed > 0 ? parsed : 0
  }
}
