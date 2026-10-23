// Pages start loading when the mouse button goes down on a link, not when
// it comes back up (Fernando, 2026-10-18: the app always feels fast): the
// ~100-200 ms between press and click are no longer spent waiting.
//
// Turbo's own prefetch is off (layout: it asked for every link the pointer
// rested on). On a press, this turns it on for that one link only: Turbo
// starts the request (the same it would make on the click, also for links
// that open in the modal) and the click uses it. One request per click, as
// before. Turbo skips what it never prefetches: other sites, downloads,
// links with a method or a confirmation, data-turbo="false".
function prefetchOnPress(event) {
  if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

  const link = event.target.closest?.("a[href]")
  const meta = document.querySelector('meta[name="turbo-prefetch"]')
  if (!link || !meta) return

  const setting = meta.content
  meta.content = "true"
  try {
    link.dispatchEvent(new MouseEvent("mouseenter"))
  } finally {
    meta.content = setting
  }
}

document.addEventListener("mousedown", prefetchOnPress, true)
