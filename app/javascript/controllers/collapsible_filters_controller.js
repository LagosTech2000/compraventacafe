import { Controller } from "@hotwired/stimulus"

// Filters stay open on wide screens; on phones they fold away unless a
// filter is active, so the list is visible without scrolling.
export default class extends Controller {
  static values = { active: Boolean }

  connect() {
    this.element.open = this.activeValue || window.matchMedia("(min-width: 40rem)").matches
  }
}
