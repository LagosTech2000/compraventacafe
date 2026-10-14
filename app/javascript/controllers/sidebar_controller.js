import { Controller } from "@hotwired/stimulus"

// The left navigation (layouts/_sidebar): collapses to its icons and back.
// The state goes on <body> (the page's padding follows it) and in a cookie,
// so the next page comes from the server already collapsed (SidebarState).
export default class extends Controller {
  static targets = ["toggle"]
  static values = { cookie: String, collapseLabel: String, expandLabel: String }

  toggle() {
    const collapsed = document.body.classList.toggle("sidebar-collapsed")
    document.cookie = `${this.cookieValue}=${collapsed ? 1 : 0}; path=/; max-age=31536000; SameSite=Lax`

    const label = collapsed ? this.expandLabelValue : this.collapseLabelValue
    this.toggleTarget.setAttribute("aria-expanded", String(!collapsed))
    this.toggleTarget.setAttribute("aria-label", label)
    this.toggleTarget.title = label
  }
}
