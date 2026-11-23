import { Controller } from "@hotwired/stimulus"

// A receipt's photo (Fernando, 2026-11-18: «comprobante con la cámara del
// celular»): a phone's photo weighs several MB and ExpenseReceipt takes 1
// MB, so a picture is shrunk in the browser to a JPEG of at most `size`
// pixels per side before sending. A PDF, or a picture the browser can't
// read, goes as it is and the server decides.
//
// «Tomar foto» (Fernando, 2026-11-22): a button after the field opens the
// phone's camera (a hidden input with `capture`, never sent: it has no
// name) and its picture goes into the field, shrunk like any other. On a
// computer the browser opens its file picker instead.
export default class extends Controller {
  static values = { size: { type: Number, default: 1600 }, cameraLabel: String }

  connect() {
    if (!this.cameraLabelValue || this.cameraButton) return

    this.camera = document.createElement("input")
    this.camera.type = "file"
    this.camera.accept = "image/*"
    this.camera.setAttribute("capture", "environment")
    this.camera.hidden = true
    this.camera.dataset.receiptCamera = ""
    this.camera.addEventListener("change", () => this.takePicture())

    this.cameraButton = document.createElement("button")
    this.cameraButton.type = "button"
    this.cameraButton.className = "btn btn-sm mt-2"
    this.cameraButton.textContent = this.cameraLabelValue
    this.cameraButton.dataset.receiptCameraButton = ""
    this.cameraButton.addEventListener("click", () => this.camera.click())

    this.element.after(this.cameraButton, this.camera)
  }

  disconnect() {
    this.cameraButton?.remove()
    this.camera?.remove()
    this.cameraButton = this.camera = null
  }

  async takePicture() {
    const file = this.camera.files[0]
    if (!file) return

    this.put(file)
    this.camera.value = ""
    await this.change()
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }

  async change() {
    const input = this.element
    const file = input.files[0]
    if (!file || !file.type.startsWith("image/")) return

    try {
      this.put(await this.shrink(file))
      input.dataset.shrunk = "true"
    } catch {
      // Sent as it is.
    }
  }

  put(file) {
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.element.files = transfer.files
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
