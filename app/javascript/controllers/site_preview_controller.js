import { Controller } from "@hotwired/stimulus"

// Site settings form: the navigation bar preview follows the name typed and
// the logo picked, and a file that is too big or not an image is refused
// before sending (the server checks it again by its content).
const TYPES = ["image/png", "image/jpeg", "image/webp", "image/gif"]

export default class extends Controller {
  static targets = ["name", "title", "file", "image", "bean", "remove"]
  static values = { maxBytes: Number, tooBig: String, notAnImage: String }

  disconnect() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }

  rename() {
    this.titleTarget.textContent = this.nameTarget.value.trim() || "—"
  }

  pick() {
    const file = this.fileTarget.files[0]
    let message = ""
    if (file && !TYPES.includes(file.type)) message = this.notAnImageValue
    else if (file && file.size > this.maxBytesValue) message = this.tooBigValue
    this.fileTarget.setCustomValidity(message)
    if (message) this.fileTarget.reportValidity()

    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = file && !message ? URL.createObjectURL(file) : null
    if (this.objectUrl && this.hasRemoveTarget) this.removeTarget.checked = false
    this.show(this.objectUrl || this.savedLogo)
  }

  toggleRemove() {
    this.show(this.removeTarget.checked ? null : (this.objectUrl || this.savedLogo))
  }

  show(url) {
    this.imageTarget.hidden = !url
    this.beanTarget.hidden = !!url
    if (url) this.imageTarget.src = url
  }

  get savedLogo() {
    return this.hasRemoveTarget && !this.removeTarget.checked ? this.imageTarget.dataset.saved : null
  }
}
