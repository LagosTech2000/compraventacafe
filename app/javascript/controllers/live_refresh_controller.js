import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Live pages (LiveUpdates): when someone else changes the data, the page
// refreshes by morphing. Two things on top of Turbo's:
//
// - While a window is open (a modal with a form, the help guide) the
//   refresh waits: morphing would empty it and lose what is typed. It runs
//   once the last window closes.
// - What is the user's stays: toasts on screen, which <details> (the
//   filters on a phone, "Ver los datos") are open or closed, and attributes
//   an element marks with data-live-keep.
// - What changed shows: rows that arrive glow in, and figures whose value
//   changed pulse. Rows are list items with an id (tr, li, .data-card);
//   figures are .stat values and [data-live-value].
// On <body>.
const ROWS = "main tr[id], main li[id], main .data-card[id]"
const VALUES = "main .stat dd, main [data-live-value]"

export default class extends Controller {
  connect() {
    document.addEventListener("turbo:before-stream-render", this.intercept)
    document.addEventListener("turbo:before-render", this.remember)
    document.addEventListener("turbo:morph", this.highlight)
    document.addEventListener("turbo:before-morph-element", this.keepElement)
    document.addEventListener("turbo:before-morph-attribute", this.keepAttribute)
    document.addEventListener("turbo:load", this.forget)
    this.element.addEventListener("close", this.resume, true)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.intercept)
    document.removeEventListener("turbo:before-render", this.remember)
    document.removeEventListener("turbo:morph", this.highlight)
    document.removeEventListener("turbo:before-morph-element", this.keepElement)
    document.removeEventListener("turbo:before-morph-attribute", this.keepAttribute)
    document.removeEventListener("turbo:load", this.forget)
    this.element.removeEventListener("close", this.resume, true)
  }

  intercept = (event) => {
    if (event.target.getAttribute("action") !== "refresh" || !this.windowOpen()) return

    this.pending = true
    event.detail.render = () => {}
  }

  resume = () => {
    if (!this.pending || this.windowOpen()) return

    this.pending = false
    Turbo.session.refresh(document.baseURI)
  }

  // A region already showing toasts stays as it is; a new one (the page's
  // own notice, e.g. after saving) fills in normally.
  keepElement = (event) => {
    if (event.target.closest?.(".toast-region")?.querySelector(".toast")) event.preventDefault()
  }

  // Open <details> stay open, and an element can keep attributes its
  // JavaScript sets (data-live-keep="hidden", e.g. the live filters' button).
  keepAttribute = (event) => {
    const { attributeName } = event.detail
    const kept = event.target.dataset?.liveKeep?.split(" ") || []
    if ((attributeName === "open" && event.target.tagName === "DETAILS") || kept.includes(attributeName)) event.preventDefault()
  }

  forget = () => {
    this.pending = false
  }

  windowOpen() {
    return document.querySelector("dialog[open]") !== null
  }

  // Before a morph: which rows there are and what each figure says.
  remember = (event) => {
    if (event.detail.renderMethod !== "morph") return

    this.rows = new Set(Array.from(document.querySelectorAll(ROWS), (row) => row.id))
    this.values = new Map(this.figures().map(([key, element]) => [key, element.textContent.trim()]))
  }

  highlight = () => {
    if (!this.rows) return

    document.querySelectorAll(ROWS).forEach((row) => {
      if (!this.rows.has(row.id)) this.animate(row, "live-new")
    })
    this.figures().forEach(([key, element]) => {
      const before = this.values.get(key)
      if (before !== undefined && before !== element.textContent.trim()) this.animate(element, "live-changed")
    })
    this.rows = null
  }

  // [key, element] per figure, known by its data-live-value or its .stat's
  // label; repeated labels get their order as well.
  figures() {
    const seen = new Map()
    return Array.from(document.querySelectorAll(VALUES), (element) => {
      const label = element.dataset.liveValue || element.closest(".stat")?.querySelector("dt")?.textContent.trim() || ""
      const count = seen.get(label) || 0
      seen.set(label, count + 1)
      return [`${label}#${count}`, element]
    })
  }

  animate(element, name) {
    element.classList.remove(name)
    void element.offsetWidth // restart the animation if it was running
    element.classList.add(name)
    element.addEventListener("animationend", () => element.classList.remove(name), { once: true })
  }
}
