import { Controller } from "@hotwired/stimulus"

// Task form: shows how many took part and each one's part, the value split
// in equal parts (PayrollTask#shares on the server, which also spreads the
// leftover cents). "Todos" / "Ninguno" pick or clear everyone at once.
export default class extends Controller {
  static targets = ["amount", "member", "share", "count"]
  static values = { countLabels: Object }

  all() {
    this.memberTargets.forEach((box) => { box.checked = true })
    this.update()
  }

  none() {
    this.memberTargets.forEach((box) => { box.checked = false })
    this.update()
  }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    if (!this.hasShareTarget) return

    const amount = parseFloat(this.amountTarget.value)
    const count = this.memberTargets.filter((box) => box.checked).length
    this.shareTarget.textContent = amount > 0 && count > 0 ? `L ${this.money.format(Math.floor(amount * 100 / count) / 100)}` : "—"
    if (this.hasCountTarget) {
      const labels = this.countLabelsValue
      this.countTarget.textContent = (count === 1 ? labels.one : labels.other || "").replace("%{count}", count)
    }
  }
}
