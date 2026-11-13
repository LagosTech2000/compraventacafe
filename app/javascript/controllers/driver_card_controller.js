import { Controller } from "@hotwired/stimulus"

// The driver of a shipment (Fernando, 2026-11-13): «Editar» to the right of
// the select opens the chosen driver's person in the modal, and below it
// their identity and phone (sales/driver_cards#show) follow the choice and
// load again once the person is saved ("person:updated").
export default class extends Controller {
  static targets = ["select", "edit", "frame"]
  static values = { url: String }

  connect() { this.show() }

  show() {
    const option = this.selectTarget.selectedOptions[0]
    const id = option?.value
    const editUrl = option?.dataset.editUrl
    if (this.hasEditTarget) {
      this.editTarget.hidden = !(id && editUrl)
      if (editUrl) this.editTarget.href = editUrl
    }
    if (!this.hasFrameTarget) return
    if (id) {
      const src = this.urlValue.replace("__id__", id)
      if (this.frameTarget.getAttribute("src") !== src) this.frameTarget.src = src
      this.frameTarget.hidden = false
    } else {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.replaceChildren()
      this.frameTarget.hidden = true
    }
  }

  // A person edited in the modal: the card again if it is the driver's.
  reload({ detail: { id } }) {
    const option = this.selectTarget.selectedOptions[0]
    if (this.hasFrameTarget && option?.value && String(option.dataset.personId) === String(id)) this.frameTarget.reload()
  }
}
