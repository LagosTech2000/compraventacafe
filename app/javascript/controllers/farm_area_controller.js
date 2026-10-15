import { Controller } from "@hotwired/stimulus"

// The farm's land in manzanas, hectares and square meters (Fernando,
// 2026-10-14): typing in one box calculates the other two. The box typed is
// what is sent (hidden area_value + area_unit); emptying it empties all.
// Factors are square meters per unit (FarmArea::SQUARE_METERS); the server
// keeps the figure as typed and calculates the rest again.
const DECIMALS = { manzana: 2, hectare: 2, square_meter: 0 }

export default class extends Controller {
  static targets = ["input", "value", "unit", "source", "sourceName"]
  static values = { factors: Object }

  typed(event) {
    const source = event.target
    const unit = source.dataset.unit
    const value = Number.parseFloat(source.value)

    if (source.value.trim() === "" || Number.isNaN(value)) {
      this.inputTargets.forEach((input) => { if (input !== source) input.value = "" })
      this.valueTarget.value = ""
      this.unitTarget.value = ""
      this.sourceTarget.hidden = true
      return
    }

    const squareMeters = value * this.factorsValue[unit]
    for (const input of this.inputTargets) {
      if (input === source) continue
      const target = input.dataset.unit
      input.value = this.round(squareMeters / this.factorsValue[target], DECIMALS[target])
    }
    this.valueTarget.value = source.value
    this.unitTarget.value = unit
    this.sourceNameTarget.textContent = source.labels[0]?.textContent.trim() || ""
    this.sourceTarget.hidden = false
  }

  round(number, decimals) {
    return String(Number(number.toFixed(decimals)))
  }
}
