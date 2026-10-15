import { cable } from "@hotwired/turbo-rails"

// Keeps one PresenceChannel subscription while signed in (Presence): made
// once and kept across Turbo visits, so moving between pages does not make
// the user go and come back. The layout marks signed-in pages with
// <meta name="presence">; a page without it (the sign-in page after
// signing out) drops the subscription.
//
// It also tells the channel which page is open ("visit"): each Turbo visit,
// each page opened in a modal or drawer, and the page underneath again when
// the modal closes. Only the user with id 1 sees it (Presence::WATCHER_IDS).
let subscription = null
let connected = false
let page = null

function meta() {
  return document.querySelector("meta[name='presence']")
}

async function report(next) {
  page = next
  if (subscription && connected) (await subscription).perform("visit", page)
}

function currentPage() {
  return { path: location.pathname + location.search, title: meta()?.dataset.title || "" }
}

async function sync() {
  const signedIn = meta() !== null

  if (signedIn && !subscription) {
    subscription = cable.subscribeTo({ channel: "PresenceChannel" }, {
      connected() { connected = true; if (page) this.perform("visit", page) },
      disconnected() { connected = false }
    })
  } else if (!signedIn && subscription) {
    const current = subscription
    subscription = null
    connected = false
    ;(await current).unsubscribe()
  }
  if (signedIn) report(currentPage())
}

// A page opened in a modal frame (modal, modal_2…).
function frameLoaded({ target }) {
  if (!target.id?.startsWith("modal") || !target.src) return

  const url = new URL(target.src, location.href)
  const title = target.querySelector("[data-presence-title]")?.dataset.presenceTitle || ""
  report({ path: url.pathname + url.search, title })
}

// A modal closed: back to the page underneath, unless another one is still open.
function dialogClosed({ target }) {
  if (!target.classList?.contains("modal") || !meta()) return
  if (document.querySelector("dialog.modal[open]")) return

  report(currentPage())
}

document.addEventListener("turbo:load", sync)
document.addEventListener("turbo:frame-load", frameLoaded)
document.addEventListener("close", dialogClosed, true)
