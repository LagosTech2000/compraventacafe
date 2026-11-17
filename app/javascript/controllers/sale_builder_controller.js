import { Controller } from "@hotwired/stimulus"

// «Nueva venta»: the shipments chosen and the price, as a preview. The
// server (SaleIssuer) repeats it on save and its result is the one kept.
//
//   net        = Σ buyer's net of the chosen shipments
//   difference = net − Σ local net (lb and %), and in lempiras at the price per pound
//   QQ         = net ÷ the sale's pounds per quintal (120 unless changed)
//   total      = net ÷ pounds per quintal × price (by the quintal) or net × price (by the pound)
//
// The price's label follows the unit (per quintal or per pound), and the
// pounds per quintal only show by the quintal. A sale has one coffee state:
// choosing shipments of two says so.
export default class extends Controller {
  static targets = ["shipment", "unit", "price", "priceLabel", "quintalField", "quintalPounds", "count", "net", "quintals",
                    "difference", "differenceMoney", "total", "mixed", "differenceBox"]
  static values = { tolerance: Number, countOne: String, countOther: String }

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
    const unit = this.unitTargets.find((radio) => radio.checked)?.value
    const quintalPounds = parseFloat(this.quintalPoundsTarget.value)
    const byQuintal = unit === "quintal"

    this.priceLabelTargets.forEach((label) => { label.hidden = label.dataset.unit !== (byQuintal ? "quintal" : "pound") })
    this.quintalFieldTarget.hidden = !byQuintal
    // Hidden by the pound: it keeps its value (120 by default) but asks nothing.
    this.quintalPoundsTarget.required = byQuintal
    // A shipment without the local scale has no origin net: no difference then.
    const complete = chosen.every((box) => box.dataset.originNet !== undefined && box.dataset.originNet !== "")
    const origin = complete ? this.round(chosen.reduce((sum, box) => sum + parseFloat(box.dataset.originNet), 0)) : 0
    const states = new Set(chosen.map((box) => box.dataset.coffeeState))

    this.countTarget.textContent = (chosen.length === 1 ? this.countOneValue : this.countOtherValue).replace("%{count}", chosen.length)
    this.netTarget.textContent = chosen.length ? this.pounds.format(net) : "—"
    this.quintalsTarget.textContent = chosen.length && quintalPounds > 0 ? this.pounds.format(this.round(net / quintalPounds)) : "—"
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
    const pricePerPound = byQuintal ? (quintalPounds > 0 ? price / quintalPounds : NaN) : price
    if (chosen.length && pricePerPound > 0) {
      // The same order as the server (Sale.amount_for): ÷ pounds per quintal, then × price.
      const total = byQuintal ? net / quintalPounds * price : net * price
      this.totalTarget.textContent = `L ${this.pounds.format(this.round(total))}`
    } else {
      this.totalTarget.textContent = "—"
    }
    this.showDifferenceMoney(chosen.length && complete ? this.round(net - origin) : 0, pricePerPound)
  }

  // "−427.77 lb = L 27,805.05 que no se cobran a este precio"
  showDifferenceMoney(difference, pricePerPound) {
    const target = this.differenceMoneyTarget
    const show = difference !== 0 && pricePerPound > 0
    target.hidden = !show
    if (!show) return

    const amount = this.round(Math.abs(difference) * pricePerPound)
    target.textContent = target.dataset[difference < 0 ? "less" : "more"].replace("%{amount}", `L ${this.pounds.format(amount)}`)
  }

  round(value) {
    return Math.round(value * 100) / 100
  }
}
