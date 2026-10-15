import { Controller } from "@hotwired/stimulus"

// The card beside the loan form: loads the picked person's card
// (loans/borrowers#show) into its frame each time the picker changes
// ("record-picker:picked"), and goes back to the hint when none is picked.
export default class extends Controller {
  static targets = ["frame", "placeholder"]
  static values = { url: String }

  show({ detail: { id } }) {
    if (id) {
      this.frameTarget.src = this.urlValue.replace("__id__", id)
    } else {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.replaceChildren(this.placeholderTarget.content.cloneNode(true))
    }
  }
}
