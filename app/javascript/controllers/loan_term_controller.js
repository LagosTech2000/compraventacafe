import { Controller } from "@hotwired/stimulus"

// The loan's term in days, between its date and its due date: typing the
// days fills the due date, and picking the due date shows the days. Moving
// the loan's date keeps the days and moves the due date. Only the dates are
// sent; the days help fill them.
const DAY = 24 * 60 * 60 * 1000

export default class extends Controller {
  static targets = ["disbursed", "days", "due"]

  connect() {
    this.showDays()
  }

  disbursedChanged() {
    if (this.daysTarget.value !== "") this.fillDue()
    else this.showDays()
  }

  fillDue() {
    const start = this.parse(this.disbursedTarget.value)
    const days = Number.parseInt(this.daysTarget.value, 10)
    if (start === null || Number.isNaN(days) || days < 0) return

    this.dueTarget.value = new Date(start + days * DAY).toISOString().slice(0, 10)
  }

  showDays() {
    const start = this.parse(this.disbursedTarget.value)
    const due = this.parse(this.dueTarget.value)
    this.daysTarget.value = start === null || due === null ? "" : String(Math.round((due - start) / DAY))
  }

  // "2026-10-12" → milliseconds at UTC midnight, so no time zone shifts a day.
  parse(value) {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
    return match ? Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])) : null
  }
}
