import { Controller } from "@hotwired/stimulus"

// A profile photo field (shared/_photo_field): shows the picture chosen and
// shrinks it in the browser to a JPEG of at most `size` pixels per side
// before sending it, so a phone's photo (several MB) fits ProfilePhoto's
// limit. If the browser can't, the original goes and the server decides.
export default class extends Controller {
  static targets = ["input", "preview", "initials", "remove"]
  static values = { size: { type: Number, default: 512 } }

  async change() {
    const file = this.inputTarget.files[0]
    if (!file) return

    try {
      const smaller = await this.shrink(file)
      const transfer = new DataTransfer()
      transfer.items.add(smaller)
      this.inputTarget.files = transfer.files
    } catch {
      // Not an image the browser can read: send it as it is.
    }
    this.show(URL.createObjectURL(this.inputTarget.files[0]))
    if (this.hasRemoveTarget) this.removeTarget.checked = false
  }

  show(url) {
    this.previewTarget.src = url
    this.previewTarget.hidden = false
    if (this.hasInitialsTarget) this.initialsTarget.hidden = true
  }

  async shrink(file) {
    const image = await createImageBitmap(file, { imageOrientation: "from-image" })
    const scale = Math.min(1, this.sizeValue / Math.max(image.width, image.height))
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(image.width * scale)
    canvas.height = Math.round(image.height * scale)
    canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height)
    const blob = await new Promise((resolve, reject) => canvas.toBlob((result) => result ? resolve(result) : reject(), "image/jpeg", 0.85))
    return new File([ blob ], "foto.jpg", { type: "image/jpeg" })
  }
}
