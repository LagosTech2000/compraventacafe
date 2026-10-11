import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// "Cargar más" of a long list: loads the next page as a turbo stream when
// the button comes near the screen (or is pressed). The stream appends the
// rows and replaces this button with the next one, or with the end note.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      // After a failure only the button retries, so a broken page is not asked again and again.
      if (!this.failed && entries.some((entry) => entry.isIntersecting)) this.load()
    }, { rootMargin: "600px 0px" })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async load() {
    if (this.loading) return
    this.loading = true
    const label = this.element.textContent
    this.element.textContent = this.element.dataset.loadingText
    this.element.setAttribute("aria-busy", "true")
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      if (!response.ok) throw new Error(response.statusText)
      Turbo.renderStreamMessage(await response.text())
    } catch {
      // Leave the button to try again by hand.
      this.element.textContent = label
      this.element.removeAttribute("aria-busy")
      this.loading = false
      this.failed = true
    }
  }
}
