import { Controller } from "@hotwired/stimulus"

// Infinite scroll of a list (shared/_pagination): when "Cargar más" comes
// near the screen (or is pressed) it asks for the next page, the same page
// with ?page=N+1, and adds its rows to the list. Works with any list without
// a server endpoint of its own:
//
// - The list's rows live in its tbody and in its card lists (ul/ol of
//   .data-card), before the anchor ([data-infinite-list-anchor]) in the
//   anchor's parent. The next page has the same shape: the n-th container
//   here gets the rows of the n-th one there.
// - A row already on the page (same id) is not added again: a list that is
//   not paged (the roles beside the employees) stays as it is.
// - The anchor is replaced by the next page's: with the next button, or
//   empty at the end.
export default class extends Controller {
  static values = { url: String, frame: String }

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
      const headers = { Accept: "text/html" }
      if (this.frameValue) headers["Turbo-Frame"] = this.frameValue
      const response = await fetch(this.urlValue, { headers })
      if (!response.ok) throw new Error(response.statusText)

      const page = new DOMParser().parseFromString(await response.text(), "text/html")
      const nextAnchor = page.querySelector("[data-infinite-list-anchor]")
      if (!nextAnchor) throw new Error("no list in the next page")

      this.append(containers(this.anchor), containers(nextAnchor))
      this.anchor.replaceWith(document.importNode(nextAnchor, true))
    } catch {
      // Leave the button to try again by hand.
      this.element.textContent = label
      this.element.removeAttribute("aria-busy")
      this.loading = false
      this.failed = true
    }
  }

  append(current, next) {
    next.forEach((container, index) => {
      const target = current[Math.min(index, current.length - 1)]
      if (!target) return

      for (const row of [...container.children]) {
        if (row.id && document.getElementById(row.id)) continue
        target.append(document.importNode(row, true))
      }
    })
  }

  get anchor() {
    return this.element.closest("[data-infinite-list-anchor]")
  }
}

// The row containers of the list that ends at `anchor`, in page order.
function containers(anchor) {
  return [...anchor.parentElement.querySelectorAll("tbody, ul, ol")].filter((element) =>
    (element.compareDocumentPosition(anchor) & Node.DOCUMENT_POSITION_FOLLOWING) &&
    (element.tagName === "TBODY" || element.querySelector(":scope > li.data-card")))
}
