import { Controller } from "@hotwired/stimulus"

// A payment of a purchase invoice (Fernando, 2026-11-15): an «abono» while
// it leaves something to pay; a «pago» when it pays the whole balance (the
// invoice is cancelled). The title and the button follow the amount typed.
export default class extends Controller {
  static targets = ["amount", "title", "submit"]
  static values = { balance: Number, texts: Object }

  connect() { this.update() }

  update() {
    const amount = parseFloat(this.amountTarget.value) || 0
    const full = amount > 0 && amount >= this.balanceValue - 0.005
    const kind = full ? "full" : "partial"
    if (this.hasTitleTarget) this.titleTarget.textContent = this.textsValue[`${kind}_title`]
    this.submitTarget.value = this.textsValue[`${kind}_submit`]
  }
}
