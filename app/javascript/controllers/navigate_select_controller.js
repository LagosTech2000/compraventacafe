import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A list whose options are pages (reports, suggested reports, saved
// filters): picking one goes there. With a frame value only that Turbo
// Frame loads (its data-turbo-action decides the history), not the page.
export default class extends Controller {
  static values = { frame: String }

  go(event) {
    const url = event.target.value
    if (!url) return
    this.hasFrameValue ? Turbo.visit(url, { frame: this.frameValue }) : Turbo.visit(url)
  }
}
