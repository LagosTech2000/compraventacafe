import { Controller } from "@hotwired/stimulus"

// A receipt's photo (Fernando, 2026-11-18: «comprobante con la cámara del
// celular»): a phone's photo weighs several MB and ExpenseReceipt takes 1
// MB, so a picture is shrunk in the browser to a JPEG of at most `size`
// pixels per side before sending. A PDF, or a picture the browser can't
// read, goes as it is and the server decides.
export default class extends Controller {
  static values = { size: { type: Number, default: 1600 } }

  async change() {
    const input = this.element
    const file = input.files[0]
    if (!file || !file.type.startsWith("image/")) return

    try {
      const smaller = await this.shrink(file)
      const transfer = new DataTransfer()
      transfer.items.add(smaller)
      input.files = transfer.files
      input.dataset.shrunk = "true"
    } catch {
      // Sent as it is.
    }
  }

  async shrink(file) {
    const image = await createImageBitmap(file, { imageOrientation: "from-image" })
    const scale = Math.min(1, this.sizeValue / Math.max(image.width, image.height))
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(image.width * scale)
    canvas.height = Math.round(image.height * scale)
    canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height)
    const blob = await new Promise((resolve, reject) => canvas.toBlob((result) => result ? resolve(result) : reject(), "image/jpeg", 0.8))
    return new File([ blob ], "comprobante.jpg", { type: "image/jpeg" })
  }
}
