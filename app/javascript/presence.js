import { cable } from "@hotwired/turbo-rails"

// Keeps one PresenceChannel subscription while signed in (Presence): made
// once and kept across Turbo visits, so moving between pages does not make
// the user go and come back. The layout marks signed-in pages with
// <meta name="presence">; a page without it (the sign-in page after
// signing out) drops the subscription.
let subscription = null

async function sync() {
  const signedIn = document.querySelector("meta[name='presence']") !== null

  if (signedIn && !subscription) {
    subscription = cable.subscribeTo({ channel: "PresenceChannel" }, {})
  } else if (!signedIn && subscription) {
    const current = subscription
    subscription = null
    ;(await current).unsubscribe()
  }
}

document.addEventListener("turbo:load", sync)
