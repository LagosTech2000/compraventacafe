import { Controller } from "@hotwired/stimulus"

// «Contar bodega» (Fernando, 2026-11-18): what the system says of the chosen
// state in the chosen warehouse, the adjustment the count makes (counted −
// system, in gross pounds, and the net it comes to at that warehouse's
// proportion) and, for who is not an administrator, a warning when it passes
// the share they may adjust. A preview: the server reads the stock again at
// the count's moment and keeps its own figures.
export default class extends Controller {
  static targets = ["warehouse", "state", "counted", "reason", "system", "difference", "net", "overShare"]
  static values = { stock: Object, limit: Number, texts: Object }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const row = this.stockValue[this.warehouseTarget.value]?.[this.stateTarget.value] || { gross: 0, net: 0, ratio: 0 }
    const counted = parseFloat(this.countedTarget.value)
    this.systemTarget.textContent = this.textsValue.system.replace("%{gross}", this.pounds.format(row.gross)).replace("%{net}", this.pounds.format(row.net))
    if (isNaN(counted)) {
      this.differenceTarget.textContent = "—"
      this.netTarget.textContent = ""
      this.overShareTarget.hidden = true
      return
    }

    const gross = Math.round((counted - row.gross) * 100) / 100
    const net = Math.round((Math.round(counted * row.ratio * 100) / 100 - row.net) * 100) / 100
    this.differenceTarget.textContent = this.textsValue.gross.replace("%{pounds}", this.signed(gross))
    this.differenceTarget.classList.toggle("text-danger", gross < 0)
    this.netTarget.textContent = this.textsValue.net.replace("%{pounds}", this.signed(net))
    this.reasonTarget.required = gross !== 0 || net !== 0
    const percent = row.gross > 0 ? Math.abs(gross) * 100 / row.gross : (gross === 0 ? 0 : Infinity)
    this.overShareTarget.hidden = !(this.hasLimitValue && this.limitValue > 0 && percent > this.limitValue)
  }

  signed(value) {
    return `${value > 0 ? "+" : value < 0 ? "−" : ""}${this.pounds.format(Math.abs(value))}`
  }
}
