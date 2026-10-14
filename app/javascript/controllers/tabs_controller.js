import { Controller } from "@hotwired/stimulus"

// Tabs inside one page (e.g. the pending work in the modal): only the chosen
// panel shows, without asking the server nor leaving the window. Arrow keys,
// Home and End move between tabs (WAI-ARIA tabs pattern).
export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    this.show(this.tabTargets.indexOf(event.currentTarget))
  }

  key(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    const last = this.tabTargets.length - 1
    const next = { ArrowRight: index + 1, ArrowLeft: index - 1, Home: 0, End: last }[event.key]
    if (next === undefined) return

    event.preventDefault()
    this.show(next > last ? 0 : next < 0 ? last : next)
    this.tabTargets[this.current].focus()
  }

  show(index) {
    this.current = index
    this.tabTargets.forEach((tab, i) => {
      const selected = i === index
      tab.setAttribute("aria-selected", String(selected))
      tab.tabIndex = selected ? 0 : -1
      tab.classList.toggle("nav-pill-active", selected)
    })
    this.panelTargets.forEach((panel, i) => { panel.hidden = i !== index })
  }
}
