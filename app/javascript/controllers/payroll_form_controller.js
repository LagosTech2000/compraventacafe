import { Controller } from "@hotwired/stimulus"

// Payroll form: the can price only applies to coffee harvest payrolls; it is
// hidden and disabled (not sent) for the other kinds.
export default class extends Controller {
  static targets = ["kind", "harvestField"]

  update() {
    const harvest = this.kindTargets.find((radio) => radio.checked)?.value === "harvest"
    this.harvestFieldTarget.hidden = !harvest
    this.harvestFieldTarget.querySelectorAll("input").forEach((input) => { input.disabled = !harvest })
  }
}
