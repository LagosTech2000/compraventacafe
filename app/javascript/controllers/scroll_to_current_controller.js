import { Controller } from "@hotwired/stimulus"

// In a bar that scrolls sideways (phones), bring the current page's link
// into view so the user always sees where they are.
export default class extends Controller {
  connect() {
    const current = this.element.querySelector("[aria-current=page]")
    if (current && this.element.scrollWidth > this.element.clientWidth) {
      this.element.scrollLeft = current.offsetLeft - (this.element.clientWidth - current.offsetWidth) / 2
    }
  }
}
