import { Controller } from "@hotwired/stimulus"

// The producer's farms in its form (Fernando, 2026-10-13): a dropdown with
// the ones it has and "Agregar finca", which asks the name in a small window
// and adds it to the dropdown. A new one travels as a hidden
// producer[new_farm_names][] and is created when the producer is saved
// (Producer#new_farm_names: an existing name, written differently, is reused).
export default class extends Controller {
  static targets = ["select", "inputs", "dialog", "name", "error", "remove", "empty"]
  static values = { newLabel: String, blankMessage: String }

  connect() {
    this.toggleRemove()
  }

  open() {
    this.nameTarget.value = ""
    this.errorTarget.hidden = true
    this.dialogTarget.showModal()
    this.nameTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  // Enter in the name adds it; it never submits the producer's form.
  key(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.add()
  }

  add() {
    const name = this.nameTarget.value.replace(/\s+/g, " ").trim()
    if (name === "") {
      this.errorTarget.textContent = this.blankMessageValue
      this.errorTarget.hidden = false
      this.nameTarget.focus()
      return
    }

    // Already in the list (any case or spacing): choose that one.
    const existing = [ ...this.selectTarget.options ].find((option) => option.dataset.name && this.same(option.dataset.name, name))
    if (existing) {
      this.selectTarget.value = existing.value
    } else {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "producer[new_farm_names][]"
      input.value = name
      this.inputsTarget.append(input)

      const option = new Option(`${name} ${this.newLabelValue}`, `new:${name}`, true, true)
      option.dataset.name = name
      option.dataset.new = "true"
      this.selectTarget.append(option)
    }
    this.emptyTargets.forEach((option) => option.remove())
    this.selectTarget.disabled = false
    this.toggleRemove()
    this.close()
  }

  // Only a farm added in this form can be taken out again.
  remove() {
    const option = this.selectTarget.selectedOptions[0]
    if (!option?.dataset.new) return

    const input = [ ...this.inputsTarget.querySelectorAll("input") ].find((field) => field.value === option.dataset.name)
    input?.remove()
    option.remove()
    this.toggleRemove()
  }

  toggleRemove() {
    this.removeTarget.hidden = !this.selectTarget.selectedOptions[0]?.dataset.new
  }

  same(a, b) {
    const normal = (text) => text.replace(/\s+/g, " ").trim().toLocaleLowerCase("es")
    return normal(a) === normal(b)
  }
}
