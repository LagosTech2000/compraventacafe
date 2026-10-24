import { Controller } from "@hotwired/stimulus"

// Suggests the account by the payment method (Control financiero): cash →
// the box, transfer or check → the bank, as each account says it is the
// default for (MoneyAccount#default_for). Once the user picks an account
// by hand, changing the method no longer moves it.
export default class extends Controller {
  static targets = ["method", "account"]
  static values = { defaults: Object }

  connect() {
    this.touched = this.accountTarget.value !== "" && this.accountTarget.value !== this.suggestion()
    if (this.accountTarget.value === "") this.suggest()
  }

  pick() {
    this.touched = true
  }

  suggest() {
    if (this.touched || !this.hasMethodTarget) return
    const account = this.suggestion()
    if (account !== undefined) this.accountTarget.value = account
  }

  suggestion() {
    if (!this.hasMethodTarget) return undefined
    const id = this.defaultsValue[this.methodTarget.value]
    return id ? String(id) : undefined
  }
}
