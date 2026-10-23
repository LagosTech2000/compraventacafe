import { Controller } from "@hotwired/stimulus"

// Opens the browser's print dialog: with the button, or once by itself
// when the page comes for that (auto: a private document just recorded,
// Loans::DocumentPrintsController). The ?print=1 that asked for it leaves
// the address, so reloading the page does not open it again.
export default class extends Controller {
  static values = { auto: Boolean }

  connect() {
    if (!this.autoValue) return

    const url = new URL(window.location.href)
    url.searchParams.delete("print")
    window.history.replaceState(window.history.state, "", url)
    requestAnimationFrame(() => this.print())
  }

  print() {
    window.print()
  }
}
