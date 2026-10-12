import { Controller } from "@hotwired/stimulus"

// A notice or alert shown as a toast (shared/_flash). It slides in, can be
// closed, and with a timeout goes away by itself; the time stops while the
// pointer or the focus is on it, so it is not gone while being read. The
// progress bar shows the time left. It is removed before Turbo caches the
// page, so going back does not show it again.
export default class extends Controller {
  static targets = ["progress"]
  static values = { timeout: Number }

  connect() {
    // Moved into a modal and back (toast_region_controller.js): it goes on
    // with the time it had left.
    this.remaining = Number(this.element.dataset.remaining) || this.timeoutValue
    this.removeBeforeCache = () => this.element.remove()
    document.addEventListener("turbo:before-cache", this.removeBeforeCache)
    requestAnimationFrame(() => this.element.classList.add("toast-shown"))
    this.resume()
  }

  disconnect() {
    this.pause()
    this.element.dataset.remaining = this.remaining
    clearTimeout(this.timer)
    document.removeEventListener("turbo:before-cache", this.removeBeforeCache)
  }

  pause() {
    if (!this.timer) return
    clearTimeout(this.timer)
    this.timer = null
    this.remaining -= Date.now() - this.startedAt
    if (this.hasProgressTarget) {
      this.progressTarget.style.transition = "none"
      this.progressTarget.style.transform = `scaleX(${Math.max(this.remaining, 0) / this.timeoutValue})`
    }
  }

  resume() {
    if (!this.timeoutValue || this.timer || this.leaving) return
    this.startedAt = Date.now()
    this.timer = setTimeout(() => this.dismiss(), this.remaining)
    if (this.hasProgressTarget) {
      const bar = this.progressTarget
      bar.style.transition = "none"
      bar.style.transform = `scaleX(${this.remaining / this.timeoutValue})`
      bar.getBoundingClientRect() // start the transition from where it was
      bar.style.transition = `transform ${this.remaining}ms linear`
      bar.style.transform = "scaleX(0)"
    }
  }

  // Slides out, then leaves the page.
  dismiss() {
    if (this.leaving) return
    this.leaving = true
    clearTimeout(this.timer)
    this.element.classList.remove("toast-shown")
    this.element.classList.add("toast-leaving")
    const remove = () => this.element.remove()
    this.element.addEventListener("transitionend", remove, { once: true })
    setTimeout(remove, 400) // also when transitions are off (reduced motion)
  }
}
