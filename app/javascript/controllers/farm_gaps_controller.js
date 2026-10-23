import { Controller } from "@hotwired/stimulus"

// Under the farm of a purchase (Fernando, 2026-10-18, like the producer's
// notice): which of the chosen farm's details are still empty
// (Farm#missing_fields, kept on its option by producer_farms_controller.js),
// with "Completar datos", which opens its form in a modal without losing the
// purchase. Only a notice: none of them is required.
export default class extends Controller {
  static targets = ["select", "notice", "text", "link"]
  static values = { message: String, editUrl: String }

  connect() {
    this.render()
  }

  render() {
    const option = this.selectTarget.selectedOptions[0]
    const missing = option?.value ? JSON.parse(option.dataset.missing || "[]") : []
    this.noticeTarget.hidden = missing.length === 0
    if (missing.length === 0) return

    this.textTarget.textContent = this.messageValue.replace("%{fields}", missing.join(", "))
    if (this.hasLinkTarget) this.linkTarget.href = this.editUrlValue.replace("__id__", option.value)
  }
}
