import { Controller } from "@hotwired/stimulus"

// The card beside a form that picks a record (the person of a loan,
// loans/borrowers#show; the producer of a purchase, trading/producer_cards#show):
// loads the picked record's card into its frame each time the picker changes
// ("record-picker:picked"), and goes back to the hint when none is picked.
export default class extends Controller {
  static targets = ["frame", "placeholder"]
  static values = { url: String }

  show({ detail: { id } }) {
    if (!this.hasFrameTarget) return
    if (id) {
      this.frameTarget.src = this.urlValue.replace("__id__", id)
    } else {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.replaceChildren(this.placeholderTarget.content.cloneNode(true))
    }
  }

  // The record edited in the modal (e.g. "producer:updated"): its card again.
  reload({ detail: { id } }) {
    if (!this.hasFrameTarget) return
    const src = this.frameTarget.getAttribute("src")
    if (!src) return

    const path = (url) => new URL(url, window.location.origin).pathname
    if (path(src) === path(this.urlValue.replace("__id__", id))) this.frameTarget.reload()
  }
}
