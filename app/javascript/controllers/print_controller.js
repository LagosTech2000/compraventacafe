import { Controller } from "@hotwired/stimulus"

// Opens the browser's print dialog.
export default class extends Controller {
  print() {
    window.print()
  }
}
