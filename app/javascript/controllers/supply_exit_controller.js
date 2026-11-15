import { Controller } from "@hotwired/stimulus"

// «Salida de insumos» (Fernando, 2026-11-14): a sale shows its buyer, price
// and account (off for a use of the business, so none of it is asked or
// sent); picking a supply puts its default price and says how much is in the
// warehouse; the total is quantity × price, and taking more than there is
// warns (the server refuses it).
export default class extends Controller {
  static targets = [ "kind", "sale", "supply", "quantity", "price", "total", "stock", "over" ]
  static values = { stockText: String, overText: String }

  connect() {
    this.toggle()
    this.update()
  }

  toggle() {
    const sale = this.kindTargets.find((radio) => radio.checked)?.value !== "business_use"
    this.saleTarget.disabled = !sale
    this.saleTarget.hidden = !sale
  }

  pickSupply() {
    const option = this.option
    if (option?.dataset.price) this.priceTarget.value = Number(option.dataset.price).toFixed(2)
    this.update()
  }

  update() {
    const option = this.option
    const quantity = parseFloat(this.quantityTarget.value) || 0
    const price = parseFloat(this.priceTarget.value) || 0
    const unit = option?.dataset.unit || ""
    const stock = option?.dataset.stock ? Number(option.dataset.stock) : null

    this.stockTarget.textContent = stock === null ? "" : this.stockTextValue.replace("%{quantity}", `${this.number(stock)} ${unit}`)
    const over = stock !== null && quantity > stock
    this.overTarget.hidden = !over
    this.overTarget.textContent = over ? this.overTextValue.replace("%{quantity}", `${this.number(stock)} ${unit}`) : ""
    this.totalTarget.textContent = `L ${this.number(quantity * price, 2)}`
  }

  get option() {
    return this.supplyTarget.selectedOptions[0]?.value ? this.supplyTarget.selectedOptions[0] : null
  }

  number(value, decimals = null) {
    const options = decimals === null ? { maximumFractionDigits: 2 } : { minimumFractionDigits: decimals, maximumFractionDigits: decimals }
    return value.toLocaleString("en-US", options)
  }
}
