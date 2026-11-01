import { Controller } from "@hotwired/stimulus"

// Check boxes where one goes alone (the loans' account, Fernando,
// 2026-11-01): checking it unchecks the others, and checking another
// unchecks it. The server keeps the same rule.
export default class extends Controller {
  static targets = ["alone", "option"]

  pick(event) {
    if (!event.target.checked) return

    const others = this.aloneTargets.includes(event.target) ? this.optionTargets : this.aloneTargets
    others.forEach((box) => { box.checked = false })
  }
}
