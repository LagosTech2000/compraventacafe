import { Controller } from "@hotwired/stimulus"

// Searchable picker (the producer of a purchase, the person of a loan, the
// employee of a payroll...). Lists that grow are not loaded with the form
// (Fernando, 2026-10-18): from 3 characters typed it asks the server
// (picker_searches#show, `url`) and shows the matches below the box; one is
// chosen with a click, or with the arrows and Enter. Typing a match's whole
// label (or pasting it) chooses it too.
//
// Choosing fills the hidden id and, with a zone field, switches it to the
// record's zone (a zone filled for the previous record is cleared if the new
// one has none; one picked by hand stays), and announces it
// ("record-picker:picked", with the record's data: farms, missing details...).
// A record created in the modal (an event such as "producer:created", wired
// in the view to #add) is chosen; one edited there (#replace) changes its
// label and zone.
export default class extends Controller {
  static targets = ["search", "list", "id", "zone"]
  static values = {
    url: String, selected: Object, missingMessage: String, texts: Object,
    minLength: { type: Number, default: 3 }, delay: { type: Number, default: 250 }
  }

  connect() {
    this.selected = this.selectedValue?.id ? this.normalize(this.selectedValue) : null
    this.autoZone = this.hasZoneTarget ? this.zoneTarget.value : ""
    this.results = []
    this.cache = new Map()
    this.active = -1
    this.searchTarget.setAttribute("role", "combobox")
    this.searchTarget.setAttribute("aria-autocomplete", "list")
    this.searchTarget.setAttribute("aria-expanded", "false")
    this.searchTarget.setAttribute("aria-controls", this.listTarget.id)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  type() {
    const text = this.text()
    if (this.selected && text === this.selected.label) return

    if (this.selected) this.choose(null)
    clearTimeout(this.timer)
    this.request?.abort()
    this.searching = false
    if (text.length < this.minLengthValue) {
      this.validate()
      text.length ? this.message(this.textsValue.short) : this.close()
      return
    }
    if (this.cache.has(text)) return this.show(text, this.cache.get(text))

    this.searching = true
    this.validate()
    this.message(this.textsValue.searching)
    this.timer = setTimeout(() => this.search(text), this.delayValue)
  }

  async search(text) {
    this.request = new AbortController()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", text)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.request.signal })
      if (!response.ok) throw new Error(response.status)
      const data = await response.json()
      this.cache.set(text, data)
      if (this.text() !== text) return

      this.searching = false
      this.show(text, data)
      this.validate()
    } catch (error) {
      if (error.name === "AbortError") return

      this.searching = false
      this.validate()
      this.message(this.textsValue.failed)
    }
  }

  show(text, { results, more }) {
    this.results = results.map((record) => this.normalize(record))
    const exact = this.results.find((record) => record.label.toLowerCase() === text.toLowerCase())
    if (exact) {
      this.choose(exact)
      return this.close()
    }

    // Left the box while it searched: only an exact match is chosen.
    if (document.activeElement !== this.searchTarget) return this.close()

    this.active = -1
    const items = this.results.map((record, index) => {
      const item = document.createElement("li")
      item.id = `${this.listTarget.id}-${index}`
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", "false")
      item.className = "picker-option"
      item.textContent = record.label
      item.dataset.index = index
      return item
    })
    if (items.length === 0) items.push(this.note(this.textsValue.empty))
    if (more) items.push(this.note(this.textsValue.more))
    this.open(items)
  }

  // Arrows move through the matches, Enter chooses, Escape closes.
  navigate(event) {
    const open = !this.listTarget.hidden && this.results.length > 0
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (!open) return
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.highlight((this.active + step + this.results.length) % this.results.length)
    } else if (event.key === "Enter" && open && this.active >= 0) {
      event.preventDefault()
      this.pick(this.active)
    } else if (event.key === "Escape" && !this.listTarget.hidden) {
      event.preventDefault()
      event.stopPropagation()
      this.close()
    }
  }

  // A press on a match keeps the focus in the box (no blur before the click).
  press(event) {
    event.preventDefault()
  }

  click(event) {
    const item = event.target.closest("[role=option]")
    if (item) this.pick(Number(item.dataset.index))
  }

  // Leaving the box closes the list; a search under way still ends, and
  // chooses the match if the text is its whole label.
  leave() {
    this.close()
    this.validate()
  }

  pick(index) {
    const record = this.results[index]
    if (!record) return

    this.choose(record)
    this.close()
  }

  // A record registered in the modal: chosen right away.
  add({ detail }) {
    this.choose(this.normalize(detail))
    this.close()
  }

  // A record edited in the modal: its new label and zone, if it is the one chosen.
  replace({ detail }) {
    const record = this.normalize(detail)
    if (!this.selected || this.selected.id !== record.id) return

    this.selected = { ...this.selected, ...record }
    this.searchTarget.value = record.label
    this.fillZone(record.zone_id)
  }

  // --- Private ---------------------------------------------------------------

  choose(record) {
    const previous = this.selected?.id || ""
    this.selected = record
    this.idTarget.value = record ? record.id : ""
    if (record) this.searchTarget.value = record.label
    this.validate()
    if ((record?.id || "") === previous) return

    if (record) this.fillZone(record.zone_id)
    this.dispatch("picked", { detail: { id: record?.id || "", record } })
  }

  fillZone(zoneId) {
    if (!this.hasZoneTarget) return

    const previousAutoZone = this.autoZone
    this.autoZone = zoneId ? String(zoneId) : ""
    if (zoneId) {
      this.zoneTarget.value = this.autoZone
    } else if (this.zoneTarget.value === previousAutoZone) {
      this.zoneTarget.value = ""
    }
  }

  // Text typed without choosing a match is not valid (the form says why;
  // while the search is under way, that it is searching).
  validate() {
    const pending = this.text() !== "" && !this.selected
    const message = this.searching ? this.textsValue.searching : this.missingMessageValue
    this.searchTarget.setCustomValidity(pending ? message : "")
  }

  highlight(index) {
    this.active = index
    this.listTarget.querySelectorAll("[role=option]").forEach((item) => {
      const current = Number(item.dataset.index) === index
      item.setAttribute("aria-selected", String(current))
      if (current) {
        this.searchTarget.setAttribute("aria-activedescendant", item.id)
        item.scrollIntoView({ block: "nearest" })
      }
    })
  }

  message(text) {
    this.results = []
    this.open([ this.note(text) ])
  }

  note(text) {
    const item = document.createElement("li")
    item.className = "picker-note"
    item.textContent = text
    return item
  }

  open(items) {
    this.listTarget.replaceChildren(...items)
    this.listTarget.hidden = false
    this.searchTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.listTarget.hidden = true
    this.listTarget.replaceChildren()
    this.active = -1
    this.searchTarget.setAttribute("aria-expanded", "false")
    this.searchTarget.removeAttribute("aria-activedescendant")
  }

  text() {
    return this.searchTarget.value.trim().replace(/\s+/g, " ")
  }

  normalize(record) {
    return { ...record, id: String(record.id) }
  }
}
