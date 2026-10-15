import { Controller } from "@hotwired/stimulus"

// Payroll form: the can price only applies to coffee harvest payrolls, and
// the value of an extra hour to daily and harvest payrolls (not by task);
// each is hidden and disabled (not sent) for the other kinds.
export default class extends Controller {
  static targets = ["kind", "harvestField", "overtimeField"]

  update() {
    const kind = this.kindTargets.find((radio) => radio.checked)?.value
    this.toggle(this.harvestFieldTarget, kind === "harvest")
    if (this.hasOvertimeFieldTarget) this.toggle(this.overtimeFieldTarget, kind !== "task")
  }

  toggle(field, shown) {
    field.hidden = !shown
    field.querySelectorAll("input").forEach((input) => { input.disabled = !shown })
  }
}
