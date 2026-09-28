import { Controller } from "@hotwired/stimulus"

// Filters the municipality list by the selected department. With no
// department selected, the municipality list stays empty and disabled.
export default class extends Controller {
  static targets = ["department", "municipality"]
  static values = { municipalities: Object, none: String, locked: String }

  change() {
    const options = this.municipalitiesValue[this.departmentTarget.value] || []
    const select = this.municipalityTarget

    select.replaceChildren(new Option(options.length ? this.noneValue : this.lockedValue, ""))
    options.forEach(([id, name]) => select.add(new Option(name, id)))
    select.disabled = options.length === 0
  }
}
