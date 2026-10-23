import { Controller } from "@hotwired/stimulus"

// Under a picked record (the producer of a purchase, the employee of a
// payroll): which of its details are still empty (missing_fields), with a
// link to complete them in a modal. Follows the record picked
// ("record-picker:picked", whose record brings its list); a record
// completed in the modal ("producer:updated", "person:updated", wired to
// #update) brings its list along. Only a notice: none is required.
export default class extends Controller {
  static targets = ["notice", "text", "link"]
  static values = { missing: Object, message: String, editUrl: String, record: String }

  connect() {
    this.render()
  }

  show({ detail: { id, record } }) {
    this.recordValue = id || ""
    if (record?.missing) this.missingValue = { ...this.missingValue, [this.recordValue]: record.missing }
    this.render()
  }

  update({ detail: { id, missing } }) {
    if (!missing) return
    this.missingValue = { ...this.missingValue, [id]: missing }
    this.render()
  }

  render() {
    const missing = this.missingValue[this.recordValue] || []
    this.noticeTarget.hidden = missing.length === 0
    if (missing.length === 0) return

    this.textTarget.textContent = this.messageValue.replace("%{fields}", missing.join(", "))
    if (this.hasLinkTarget) this.linkTarget.href = this.editUrlValue.replace("__id__", this.recordValue)
  }
}
