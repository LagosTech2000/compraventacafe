import { Controller } from "@hotwired/stimulus"

// Task form: shows each participant's part, the value split in equal parts
// (PayrollTask#shares on the server, which also spreads the leftover cents).
export default class extends Controller {
  static targets = ["amount", "member", "share"]

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    if (!this.hasShareTarget) return

    const amount = parseFloat(this.amountTarget.value)
    const count = this.memberTargets.filter((box) => box.checked).length
    this.shareTarget.textContent = amount > 0 && count > 0 ? `L ${this.money.format(Math.floor(amount * 100 / count) / 100)}` : "—"
  }
}
