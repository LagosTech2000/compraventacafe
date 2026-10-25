import { Controller } from "@hotwired/stimulus"

// New loan: «the first 10 days bring no interest» is only for an
// intermediary. Follows the person picked ("record-picker:picked", whose
// record says whether it is one); for anyone else the box is hidden,
// unchecked and not sent. The server checks it again.
export default class extends Controller {
  static targets = ["box"]

  follow({ detail: { record } }) {
    const intermediary = Boolean(record?.intermediary)
    this.element.hidden = !intermediary
    this.boxTarget.disabled = !intermediary
    if (!intermediary) this.boxTarget.checked = false
  }
}
