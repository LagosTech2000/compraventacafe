import { Controller } from "@hotwired/stimulus"

// The fortnight of the payroll sheet (Planilla interna): each day is a
// button that cycles — → 1 (full day) → ½ → —, with a hidden field holding
// what is sent. «Todos» fills a day for everyone and «Toda la quincena» an
// employee's fortnight. Each row's days, earned and total follow, with the
// rule of the Excel (StaffMember#days_in): a fortnight worked whole counts
// `nominal` days (15); otherwise the days marked, never more. Earned =
// monthly salary ÷ 30 × days; total = earned − advances. Every change is
// announced ("staff-sheet:changed") for the save bar. Only a preview: the
// server saves and calculates again.
const NEXT = { "": "1", 1: "0.5", 0.5: "" }
const DAYS_PER_MONTH = 30

export default class extends Controller {
  static targets = ["row", "days", "earned", "total", "daysTotal", "earnedTotal", "grandTotal", "payBox"]
  static values = { labels: Object, nominal: Number, dates: Number }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.number = new Intl.NumberFormat("es-HN", { maximumFractionDigits: 1 })
  }

  cycle(event) {
    const input = event.currentTarget.previousElementSibling
    this.set(input, NEXT[input.value] ?? "")
    this.update()
  }

  fillColumn(event) {
    this.element.querySelectorAll(`input[data-date='${event.currentTarget.dataset.date}']`).forEach((input) => this.set(input, "1"))
    this.update()
  }

  fillRow(event) {
    event.currentTarget.closest("tr").querySelectorAll("input[data-date]").forEach((input) => this.set(input, "1"))
    this.update()
  }

  // Marks or unmarks every employee to pay together.
  toggleAll(event) {
    this.payBoxTargets.forEach((box) => { box.checked = event.currentTarget.checked })
  }

  set(input, value) {
    if (input.disabled) return
    input.value = value
    const button = input.nextElementSibling
    button.dataset.state = value
    button.textContent = this.labelsValue[value] ?? value
  }

  update() {
    let days = 0
    let earned = 0
    let total = 0
    this.rowTargets.forEach((row, index) => {
      const rowDays = this.rowDays(row)
      const salary = parseFloat(row.dataset.salary) || 0
      const rowEarned = Math.round((salary * rowDays / DAYS_PER_MONTH) * 100) / 100
      const rowTotal = Math.round((rowEarned - (parseFloat(row.dataset.advances) || 0)) * 100) / 100
      this.daysTargets[index].textContent = this.number.format(rowDays)
      this.earnedTargets[index].textContent = this.format(rowEarned)
      this.totalTargets[index].textContent = this.format(rowTotal)
      days += rowDays
      earned += rowEarned
      total += rowTotal
    })
    this.daysTotalTarget.textContent = this.number.format(days)
    this.earnedTotalTarget.textContent = this.format(earned)
    this.grandTotalTarget.textContent = this.format(total)
    this.dispatch("changed")
  }

  // Worked whole (every day of the fortnight in the employee's dates and
  // full): the nominal days; otherwise the days marked, at most nominal.
  rowDays(row) {
    const values = [...row.querySelectorAll("input[data-date]")].map((input) => parseFloat(input.value) || 0)
    const whole = values.length === this.datesValue && values.every((value) => value === 1)
    if (whole) return this.nominalValue
    return Math.min(values.reduce((sum, value) => sum + value, 0), this.nominalValue)
  }

  format(value) {
    return `${value < 0 ? "−" : ""}L ${this.money.format(Math.abs(value))}`
  }
}
