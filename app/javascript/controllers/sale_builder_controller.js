import { Controller } from "@hotwired/stimulus"

// «Nueva venta»: the shipments chosen and the price, as a preview. The
// server (SaleIssuer) repeats it on save and its result is the one kept.
//
//   net        = Σ buyer's net of the chosen shipments
//   difference = net − Σ local net (lb and %)
//   QQ         = net ÷ 100 (a sale's quintal)
//   total      = net ÷ 100 × price (by the quintal) or net × price (by the pound)
//
// A sale has one coffee state: choosing shipments of two says so.
export default class extends Controller {
  static targets = ["shipment", "unit", "price", "count", "net", "quintals", "difference", "total", "mixed", "differenceBox"]
  static values = { quintalPounds: Number, tolerance: Number, countOne: String, countOther: String }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  all() {
    this.shipmentTargets.forEach((box) => { box.checked = true })
    this.update()
  }

  none() {
    this.shipmentTargets.forEach((box) => { box.checked = false })
    this.update()
  }

  update() {
    const chosen = this.shipmentTargets.filter((box) => box.checked)
    const net = this.round(chosen.reduce((sum, box) => sum + parseFloat(box.dataset.net), 0))
    const origin = this.round(chosen.reduce((sum, box) => sum + parseFloat(box.dataset.originNet), 0))
    const states = new Set(chosen.map((box) => box.dataset.coffeeState))

    this.countTarget.textContent = (chosen.length === 1 ? this.countOneValue : this.countOtherValue).replace("%{count}", chosen.length)
    this.netTarget.textContent = chosen.length ? this.pounds.format(net) : "—"
    this.quintalsTarget.textContent = chosen.length ? this.pounds.format(this.round(net / this.quintalPoundsValue)) : "—"
    this.mixedTarget.hidden = states.size < 2

    if (chosen.length && origin > 0) {
      const difference = this.round(net - origin)
      const percent = this.round(difference * 100 / origin)
      const sign = (value) => (value > 0 ? "+" : value < 0 ? "−" : "")
      this.differenceTarget.textContent =
        `${sign(difference)}${this.pounds.format(Math.abs(difference))} lb (${sign(percent)}${this.pounds.format(Math.abs(percent))} %)`
      this.differenceBoxTarget.dataset.overTolerance = (this.toleranceValue > 0 && Math.abs(percent) > this.toleranceValue) ? "true" : "false"
    } else {
      this.differenceTarget.textContent = "—"
      this.differenceBoxTarget.dataset.overTolerance = "false"
    }

    const price = parseFloat(this.priceTarget.value)
    const unit = this.unitTargets.find((radio) => radio.checked)?.value
    if (chosen.length && price > 0) {
      const total = unit === "quintal" ? net / this.quintalPoundsValue * price : net * price
      this.totalTarget.textContent = `L ${this.pounds.format(this.round(total))}`
    } else {
      this.totalTarget.textContent = "—"
    }
  }

  round(value) {
    return Math.round(value * 100) / 100
  }
}
