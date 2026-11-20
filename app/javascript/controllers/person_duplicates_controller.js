import { Controller } from "@hotwired/stimulus"

// Who is already registered like the person being written (Fernando,
// 2026-11-18): after typing the names, DNI, RTN or phone, asks the server
// (PersonDuplicates) and shows the notice in its frame. Only a notice.
const FIELDS = ["first_names", "last_names", "dni", "rtn", "phone"]

export default class extends Controller {
  static targets = ["frame"]
  static values = { url: String, except: String }

  disconnect() {
    clearTimeout(this.timer)
  }

  changed(event) {
    if (!FIELDS.includes(this.fieldOf(event.target))) return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.ask(), 400)
  }

  ask() {
    const params = new URLSearchParams()
    this.element.querySelectorAll("input[name]").forEach((input) => {
      const field = this.fieldOf(input)
      if (FIELDS.includes(field) && input.value.trim()) params.set(field, input.value.trim())
    })
    if (this.exceptValue) params.set("except_id", this.exceptValue)
    const src = `${this.urlValue}?${params}`
    if (this.frameTarget.getAttribute("src") !== src) this.frameTarget.setAttribute("src", src)
  }

  // "producer[person_attributes][first_names]" → "first_names"
  fieldOf(input) {
    return input.name?.match(/\[([a-z_]+)\]$/)?.[1]
  }
}
