import { Controller } from "@hotwired/stimulus"

// The browser tab title of content loaded into a Turbo Frame, which does
// not replace the page's <title> by itself (switching reports).
export default class extends Controller {
  static values = { title: String }

  connect() {
    if (this.titleValue) document.title = this.titleValue
  }
}
