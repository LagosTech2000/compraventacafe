import { cable } from "@hotwired/turbo-rails"
import { application } from "controllers/application"

// The fingerprint reader of this PC (Fernando, 2026-11-14), for a browser
// linked to its station (<meta name="fingerprint-station">, layout). One
// FingerprintChannel subscription kept across Turbo visits, like presence.js.
//
// When someone puts a finger on the reader (FingerprintEvents "identified"):
//   1. a page with a field for that person fills it: the searchable pickers
//      (record_picker_controller.js) of its kind, or a select whose options
//      carry data-person-id (the driver of «Nueva salida»);
//   2. a page with its own action for a person goes there
//      (data-fingerprint-visit, with __person_id__, __producer_id__,
//      __hauler_id__ in the address);
//   3. otherwise the person's panel opens in the modal (or the drawer). With
//      another window open, a notice offers to open it instead, so nothing
//      typed there is lost; the panel of another person is replaced.
// Fields are looked for in the window on top, if one is open.
//
// Enrollment progress travels to the waiting page as "fingerprint:enroll"
// events (fingerprint_enroll_controller.js); the reader's state shows in
// #fingerprint-status.
let subscription = null
let stationId = null
let state = null

function meta() {
  return document.querySelector("meta[name='fingerprint-station']")
}

function texts() {
  return JSON.parse(meta()?.dataset.texts || "{}")
}

async function sync() {
  const id = meta()?.content || null
  if (id !== stationId) {
    if (subscription) (await subscription).unsubscribe()
    subscription = null
    stationId = id
    if (id) subscription = cable.subscribeTo({ channel: "FingerprintChannel" }, { received })
  }
  showState()
}

function received(data) {
  switch (data.type) {
    case "state": state = data; showState(); break
    case "identified": identified(data.person_id); break
    case "unknown": toast(texts().unknown); break
    default:
      if (data.type?.startsWith("enroll")) window.dispatchEvent(new CustomEvent("fingerprint:enroll", { detail: data }))
  }
}

function showState() {
  const badge = document.getElementById("fingerprint-status")
  if (!badge || !state) return

  const key = !state.bridge ? "bridge_off" : (state.reader ? "ready" : "reader_off")
  badge.dataset.state = key
  badge.querySelector("[data-fingerprint-label]").textContent = texts()[key] || ""
}

async function identified(personId) {
  const response = await fetch(`/fingerprint_matches/${personId}`, { headers: { Accept: "application/json" } })
  if (!response.ok) return

  const match = await response.json()
  const dialog = topDialog()
  const scope = dialog || document
  if (fillPicker(scope, match) || fillSelect(scope, match) || visitPage(scope, match)) return

  if (dialog?.querySelector("[data-person-panel]")) return open(match.panel_url, dialog.querySelector("turbo-frame")?.id)
  if (dialog) return toast(texts().found.replace("%{name}", match.name), { label: texts().open, url: match.panel_url, frame: nextFrame(dialog) })
  open(match.panel_url, "modal")
}

function topDialog() {
  const open = [...document.querySelectorAll("dialog[open]")]
  return open[open.length - 1] || null
}

function nextFrame(dialog) {
  const frames = ["modal", "modal_2", "modal_3"]
  const current = frames.indexOf(dialog.querySelector("turbo-frame")?.id)
  return frames[Math.min(current + 1, frames.length - 1)] || "modal"
}

function visible(element) {
  return element.checkVisibility ? element.checkVisibility() : element.offsetParent !== null
}

function fillPicker(scope, match) {
  for (const element of scope.querySelectorAll("[data-controller~='record-picker']")) {
    const kind = (element.dataset.recordPickerUrlValue || "").match(/picker_search\/(\w+)/)?.[1]
    const record = kind && match.pickers[kind]
    if (!record || !visible(element)) continue

    application.getControllerForElementAndIdentifier(element, "record-picker")?.add({ detail: record })
    return true
  }
  return false
}

function fillSelect(scope, match) {
  for (const select of scope.querySelectorAll("select[data-fingerprint-person-select]")) {
    const option = [...select.options].find((each) => each.dataset.personId === String(match.person_id))
    if (!option) continue

    const mode = select.dataset.fingerprintActivate && scope.querySelector(select.dataset.fingerprintActivate)
    if (mode && !mode.checked) mode.click()
    select.value = option.value
    select.dispatchEvent(new Event("change", { bubbles: true }))
    return true
  }
  return false
}

function visitPage(scope, match) {
  const hook = scope.querySelector("[data-fingerprint-visit]")
  if (!hook) return false

  let missing = false
  const url = hook.dataset.fingerprintVisit.replace(/__(\w+)__/g, (_, key) => {
    if (match[key] == null) missing = true
    return encodeURIComponent(match[key] ?? "")
  })
  if (missing) return false

  window.Turbo.visit(url)
  return true
}

function open(url, frame) {
  const link = document.createElement("a")
  link.href = url
  link.dataset.turboFrame = frame || "modal"
  link.hidden = true
  document.body.appendChild(link)
  link.click()
  link.remove()
}

// A notice like the server's toasts (shared/_flash), with an optional link.
function toast(message, link = null) {
  if (!message) return

  let region = document.querySelector(".toast-region")
  if (!region) {
    region = document.createElement("div")
    region.className = "toast-region print:hidden"
    region.setAttribute("aria-live", "polite")
    region.setAttribute("popover", "manual")
    region.dataset.controller = "toast-region"
    document.getElementById("toasts")?.appendChild(region)
  }

  const item = document.createElement("div")
  item.className = "toast toast-notice"
  item.setAttribute("role", "status")
  item.dataset.controller = "toast"
  item.dataset.toastTimeoutValue = "7000"
  item.dataset.action = "mouseenter->toast#pause mouseleave->toast#resume focusin->toast#pause focusout->toast#resume"
  item.dataset.fingerprintToast = ""

  const text = document.createElement("p")
  text.className = "min-w-0 flex-1 pt-0.5 text-sm font-medium text-ink"
  text.textContent = message
  if (link) {
    const anchor = document.createElement("a")
    anchor.href = link.url
    anchor.dataset.turboFrame = link.frame
    anchor.className = "link ml-2"
    anchor.textContent = link.label
    text.append(" ", anchor)
  }
  const close = document.createElement("button")
  close.type = "button"
  close.className = "-mt-1 -mr-1 shrink-0 cursor-pointer rounded-full px-2 py-1 text-lg leading-none text-ink-muted"
  close.dataset.action = "toast#dismiss"
  close.setAttribute("aria-label", texts().dismiss || "")
  close.textContent = "×"
  const progress = document.createElement("span")
  progress.className = "toast-progress"
  progress.dataset.toastTarget = "progress"
  progress.setAttribute("aria-hidden", "true")
  item.append(text, close, progress)
  region.appendChild(item)
}

document.addEventListener("turbo:load", sync)
sync()
