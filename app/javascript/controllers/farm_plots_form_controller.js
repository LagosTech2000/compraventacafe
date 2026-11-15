import { Controller } from "@hotwired/stimulus"

// The plots written in a farm's form (Fernando, 2026-11-15): «Agregar
// parcela» adds a row from the template; «Quitar» removes a new one, or
// marks a saved one to be removed (_destroy) and hides it.
export default class extends Controller {
  static targets = ["list", "template", "row", "empty"]

  connect() { this.toggleEmpty() }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_PLOT/g, String(Date.now()))
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.rowTargets[this.rowTargets.length - 1].querySelector("input[type=text]")?.focus()
    this.toggleEmpty()
  }

  remove(event) {
    const row = event.target.closest("[data-farm-plots-form-target=row]")
    const destroy = row.querySelector("input[name$='[_destroy]']")
    if (row.dataset.persisted === "true" && destroy) {
      destroy.value = "1"
      row.hidden = true
      row.querySelectorAll("[required]").forEach((field) => field.removeAttribute("required"))
    } else {
      row.remove()
    }
    this.toggleEmpty()
  }

  toggleEmpty() {
    if (this.hasEmptyTarget) this.emptyTarget.hidden = this.rowTargets.some((row) => !row.hidden)
  }
}
