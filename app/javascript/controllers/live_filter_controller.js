import { Controller } from "@hotwired/stimulus"

// A list whose filters apply as the user goes, with no "Filtrar" button:
// a list, a date or a checkbox right when it changes, and the search box a
// moment after typing stops. Only the results reload (the form targets the
// list's Turbo Frame); the form itself stays, so focus and what is being
// typed are never lost. The quick periods and the × of the active filters
// set fields of this form and send it, so the form is always the one truth.
// The "Filtrar" button stays for browsers without JavaScript, hidden here.
export default class extends Controller {
  static targets = ["form", "submit"]
  static values = { delay: { type: Number, default: 350 } }

  connect() {
    this.submitTargets.forEach((button) => { button.hidden = true })
    this.lastQuery = this.query()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // A list, a date, a checkbox, or a search box left or cleared.
  change() {
    this.submit()
  }

  type(event) {
    if (!this.typing(event.target)) return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.submit(), this.delayValue)
  }

  // Quick periods and the × of an active filter: { field: value, ... }.
  apply({ params: { values } }) {
    Object.entries(values).forEach(([name, value]) => {
      const field = this.formTarget.elements[name]
      if (!field) return
      if (field.type === "checkbox") field.checked = value === field.value
      else field.value = value
    })
    this.submit()
  }

  // Only when the query changed: a search box sends both "input" and
  // "change", and the second must not ask again.
  submit() {
    clearTimeout(this.timer)
    const query = this.query()
    if (query === this.lastQuery) return
    this.lastQuery = query
    this.formTarget.requestSubmit()
  }

  query() {
    return new URLSearchParams(new FormData(this.formTarget)).toString()
  }

  typing(field) {
    return field.type === "search" || field.type === "text"
  }
}
