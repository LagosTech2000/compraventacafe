import { Controller } from "@hotwired/stimulus"

// Live preview of the purchase calculation while typing. It mirrors
// PurchaseCalculation (Ruby), which stays the source of truth: the server
// recalculates on save.
export default class extends Controller {
  static targets = ["gross", "humidity", "price", "sacks", "tare", "netWeight", "total"]
  static values = { sackWeight: Number, tarePerSack: Number }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const gross = parseFloat(this.grossTarget.value)
    const humidity = parseFloat(this.humidityTarget.value)
    const price = parseFloat(this.priceTarget.value)

    if (!(gross > 0) || !(humidity >= 0)) return this.show("—", "—", "—", "—")

    const sacks = gross / this.sackWeightValue
    const tare = Math.ceil(sacks) * this.tarePerSackValue
    const net = Math.round(Math.max((gross - tare) * (1 - humidity / 100), 0) * 100) / 100
    const total = price > 0 ? `L ${this.pounds.format(Math.round(net * price * 100) / 100)}` : "—"

    this.show(this.pounds.format(sacks), this.pounds.format(tare), this.pounds.format(net), total)
  }

  show(sacks, tare, net, total) {
    this.sacksTarget.textContent = sacks
    this.tareTarget.textContent = tare
    this.netWeightTarget.textContent = net
    this.totalTarget.textContent = total
  }
}
