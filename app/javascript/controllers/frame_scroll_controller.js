import { Controller } from "@hotwired/stimulus"

// Keeps the user where they were when a query reloads this Turbo Frame
// (sorting a column at the bottom of a report). Swapping the content makes
// the page shorter for a moment, so the browser clamps the scroll and then
// moves it again as the new content grows. To avoid it, the frame keeps its
// height while it is replaced, the scroll goes back right after, and the
// height is released once the frames inside it (the charts) have loaded.
export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:before-frame-render", this.hold)
    this.element.addEventListener("turbo:frame-render", this.restore)
    this.element.addEventListener("turbo:frame-load", this.release)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-frame-render", this.hold)
    this.element.removeEventListener("turbo:frame-render", this.restore)
    this.element.removeEventListener("turbo:frame-load", this.release)
    clearTimeout(this.releaseTimer)
  }

  hold = (event) => {
    if (event.target !== this.element) return
    this.scrollY = window.scrollY
    this.element.style.minHeight = `${this.element.offsetHeight}px`
  }

  restore = (event) => {
    if (event.target !== this.element || this.scrollY === undefined) return
    window.scrollTo(0, this.scrollY)
    requestAnimationFrame(() => window.scrollTo(0, this.scrollY))
    // If a nested frame never loads, do not keep the height for good.
    clearTimeout(this.releaseTimer)
    this.releaseTimer = setTimeout(() => this.unlock(), 3000)
  }

  // A nested frame (the charts) finished: the content has its real height.
  release = (event) => {
    if (event.target !== this.element && this.element.style.minHeight) this.unlock()
  }

  unlock() {
    clearTimeout(this.releaseTimer)
    this.element.style.minHeight = ""
    this.scrollY = undefined
  }
}
