import { Controller } from "@hotwired/stimulus"

// «Salida de insumos» (Fernando, 2026-11-14; several supplies, 2026-11-16):
// a sale shows its buyer, account and each line's price (off for a use of
// the business, so none of it is asked or sent). Lines are added and removed
// from a <template>, as in an entry. Picking a supply puts its default price
// and says how much is in the warehouse; taking more than there is, adding
// the lines of the same supply, warns (the server refuses it). Each line's
// amount is quantity × price and the total their sum. A use of the business
// says the vehicle (asked for fuel or oil of the business) and the purchase
// it went for (Fernando, 2026-11-22).
export default class extends Controller {
  static targets = [ "kind", "sale", "lines", "line", "template", "empty", "destroy", "total", "use", "vehicle", "purchase",
                     "day", "purchaseHelp", "noPurchases", "useCost" ]
  static values = { stockText: String, overText: String }

  connect() {
    if (this.visibleLines().length === 0) this.add()
    this.filterPurchases()
    this.toggle()
  }

  // Only the purchases of the dispatch's day that went with a vehicle
  // (Fernando, 2026-11-23); one of another day is unpicked.
  filterPurchases() {
    if (!this.hasPurchaseTarget || !this.hasDayTarget) return
    const day = this.dayTarget.value
    let shown = 0
    Array.from(this.purchaseTarget.options).forEach((option) => {
      if (!option.value) return
      const fits = option.dataset.day === day
      option.hidden = !fits
      option.disabled = !fits
      if (fits) shown += 1
      else if (option.selected) this.purchaseTarget.value = ""
    })
    this.purchaseTarget.disabled = shown === 0
    this.noPurchasesTarget.hidden = shown > 0
    this.purchaseHelpTarget.hidden = shown === 0
  }

  toggle() {
    const sale = this.isSale
    this.saleTarget.disabled = !sale
    this.saleTarget.hidden = !sale
    this.element.querySelectorAll("[data-sale-only]").forEach((cell) => this.setSaleCell(cell, sale))
    if (this.hasUseTarget) {
      this.useTarget.disabled = sale
      this.useTarget.hidden = sale
    }
    this.update()
  }

  // A use of the business takes the vehicle of the purchase it went for
  // (Fernando, 2026-11-22), unless one is chosen already.
  pickPurchase() {
    const vehicle = this.purchaseTarget.selectedOptions[0]?.dataset.vehicleId
    if (vehicle && !this.vehicleTarget.value) this.vehicleTarget.value = vehicle
  }

  setSaleCell(cell, sale) {
    cell.hidden = !sale
    cell.querySelectorAll("input").forEach((input) => { input.disabled = !sale })
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, String(Date.now()))
    this.linesTarget.insertAdjacentHTML("beforeend", html)
    const line = this.lineTargets[this.lineTargets.length - 1]
    line.querySelectorAll("[data-sale-only]").forEach((cell) => this.setSaleCell(cell, this.isSale))
    this.update()
    return line
  }

  addAndFocus() {
    this.add().querySelector("select")?.focus()
  }

  remove(event) {
    event.target.closest("[data-supply-exit-target~='line']").remove()
    this.update()
  }

  pickSupply(event) {
    const line = event.target.closest("[data-supply-exit-target~='line']")
    const option = this.option(line)
    const price = this.field(line, "price")
    if (option?.dataset.price && price) price.value = Number(option.dataset.price).toFixed(2)
    this.update()
  }

  update() {
    const lines = this.visibleLines()
    const taken = {}
    lines.forEach((line) => {
      const option = this.option(line)
      if (option) taken[option.value] = (taken[option.value] || 0) + (parseFloat(this.field(line, "quantity").value) || 0)
    })

    let total = 0
    lines.forEach((line) => {
      const option = this.option(line)
      const quantity = parseFloat(this.field(line, "quantity").value) || 0
      const price = parseFloat(this.field(line, "price")?.value) || 0
      const unit = option?.dataset.unit || ""
      const stock = option?.dataset.stock ? Number(option.dataset.stock) : null
      const stockText = this.field(line, "stock")
      const over = this.field(line, "over")

      stockText.textContent = stock === null ? "" : this.stockTextValue.replace("%{quantity}", `${this.number(stock)} ${unit}`)
      const tooMuch = stock !== null && taken[option.value] > stock
      over.hidden = !tooMuch
      over.textContent = tooMuch ? this.overTextValue.replace("%{quantity}", `${this.number(stock)} ${unit}`) : ""

      const amount = Math.round(quantity * price * 100) / 100
      this.field(line, "amount").textContent = `L ${this.number(amount, 2)}`
      total += amount
    })
    this.emptyTarget.hidden = lines.length > 0
    this.totalTarget.textContent = `L ${this.number(total, 2)}`
    // A use of the business, at the average cost of what came in.
    if (this.hasUseCostTarget) {
      const cost = lines.reduce((sum, line) => sum + (parseFloat(this.field(line, "quantity").value) || 0) * (parseFloat(this.option(line)?.dataset.cost) || 0), 0)
      this.useCostTarget.textContent = `L ${this.number(Math.round(cost * 100) / 100, 2)}`
    }
    // Fuel or oil of the business goes to a vehicle.
    if (this.hasVehicleTarget) this.vehicleTarget.required = !this.isSale && lines.some((line) => this.option(line)?.dataset.business === "true")
  }

  get isSale() {
    return this.kindTargets.find((radio) => radio.checked)?.value !== "business_use"
  }

  visibleLines() {
    return this.lineTargets.filter((line) => !line.hidden)
  }

  field(line, name) {
    return line.querySelector(`[data-line-field='${name}']`)
  }

  option(line) {
    const select = this.field(line, "supply")
    return select.selectedOptions[0]?.value ? select.selectedOptions[0] : null
  }

  number(value, decimals = null) {
    const options = decimals === null ? { maximumFractionDigits: 2 } : { minimumFractionDigits: decimals, maximumFractionDigits: decimals }
    return value.toLocaleString("en-US", options)
  }
}
