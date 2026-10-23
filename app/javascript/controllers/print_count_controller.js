import { Controller } from "@hotwired/stimulus"

// The card with a loan's latest prints, over its counter (loans/loans/
// _print_buttons). It opens with CSS (hover or focus); this places it on
// the screen (position: fixed), under the counter, so a table that scrolls
// sideways does not cut it. It stays inside the window.
const MARGIN = 8

export default class extends Controller {
  static targets = ["card"]

  place() {
    const counter = this.element.getBoundingClientRect()
    const card = this.cardTarget
    const width = card.offsetWidth
    const left = Math.min(Math.max(MARGIN, counter.left + counter.width / 2 - width / 2), window.innerWidth - width - MARGIN)
    const below = counter.bottom
    const fitsBelow = below + card.offsetHeight < window.innerHeight - MARGIN
    card.style.left = `${left}px`
    card.style.top = fitsBelow ? `${below}px` : `${Math.max(MARGIN, counter.top - card.offsetHeight)}px`
  }
}
