import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Paying loans with a purchase: one amount per loan. "Saldar" fills a loan
// with what it owes (or what the purchase still has); "fill all" goes loan
// by loan, the ones due first. Shows what goes to loans and what is left
// for the producer, and refuses to go over the purchase. Changing the date
// reloads the form with the debt on that date. The server checks it all.
export default class extends Controller {
  static targets = ["amount", "total", "remaining"]
  static values = { available: Number, overMessage: String, reloadUrl: String }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  fill(event) {
    const input = document.getElementById(event.currentTarget.dataset.targetId)
    input.value = ""
    const room = this.availableValue - this.sum()
    input.value = this.round(Math.min(parseFloat(event.currentTarget.dataset.owed), Math.max(room, 0))).toFixed(2)
    this.update()
  }

  fillAll() {
    this.amountTargets.forEach((input) => { input.value = "" })
    let room = this.availableValue
    this.amountTargets.forEach((input) => {
      const amount = this.round(Math.min(parseFloat(input.max), room))
      input.value = amount > 0 ? amount.toFixed(2) : ""
      room = this.round(room - Math.max(amount, 0))
    })
    this.update()
  }

  update() {
    const total = this.round(this.sum())
    const over = total > this.availableValue
    this.totalTarget.textContent = `L ${this.money.format(total)}`
    this.remainingTarget.textContent = `L ${this.money.format(this.round(this.availableValue - total))}`
    this.amountTargets.forEach((input) => input.setCustomValidity(over ? this.overMessageValue : ""))
  }

  reload(event) {
    const frame = this.element.closest("turbo-frame")
    const url = `${this.reloadUrlValue}?paid_on=${encodeURIComponent(event.target.value)}`
    if (frame) frame.src = url
    else Turbo.visit(url)
  }

  sum() {
    return this.amountTargets.reduce((total, input) => total + (parseFloat(input.value) || 0), 0)
  }

  round(value) {
    return Math.round(value * 100) / 100
  }
}
