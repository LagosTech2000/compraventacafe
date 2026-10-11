import { Controller } from "@hotwired/stimulus"

// On a season filter: picking a season clears the "from" and "to" dates of
// the same form, so the list shows the whole season instead of the days that
// were there (the purchases list starts on today).
export default class extends Controller {
  clearDates() {
    if (this.element.value === "") return

    const { from, to } = this.element.form.elements
    if (from) from.value = ""
    if (to) to.value = ""
  }
}
