import { Controller } from "@hotwired/stimulus"

// A «mark all» box over a list of boxes, and how many are marked.
export default class extends Controller {
  static targets = ["all", "item", "count", "submit"]
  static values = { label: String, none: String }

  connect() {
    this.update()
  }

  toggleAll() {
    this.itemTargets.forEach((box) => { box.checked = this.allTarget.checked })
    this.update()
  }

  update() {
    const marked = this.itemTargets.filter((box) => box.checked).length
    if (this.hasAllTarget) {
      this.allTarget.checked = marked > 0 && marked === this.itemTargets.length
      this.allTarget.indeterminate = marked > 0 && marked < this.itemTargets.length
    }
    if (this.hasCountTarget) this.countTarget.textContent = marked === 0 && this.noneValue ? this.noneValue : this.labelValue.replace("%{count}", marked)
    this.submitTargets.forEach((button) => { button.disabled = marked === 0 })
  }
}
