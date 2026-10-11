import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A list whose options are pages (reports, suggested reports, saved
// filters): picking one goes there.
export default class extends Controller {
  go(event) {
    const url = event.target.value
    if (url) Turbo.visit(url)
  }
}
