// Commas as thousands separators while typing an amount (Fernando,
// 2026-11-14: «cuando se escriba un monto, que se vean las comas como
// separadores automáticamente mientras el usuario escribe»).
//
// Every decimal number field that can reach a thousand (amounts, prices,
// pounds: inputmode="decimal", step not "any", no max or a max of 1,000 or
// more; never percents, yields or coordinates) turns into a text field that
// shows "12,345.67". Everything else keeps working with the plain number:
// - the field's `value` reads "12345.67" (the other controllers' math, the
//   specs) and writing it shows the commas;
// - the form sends it without commas (the formdata event, also for Turbo);
// - min, max and decimals are checked here, since a text field does not.
const SELECTOR = "input[type=number][inputmode=decimal]:not([step=any]), input[data-thousands]"
const enhanced = new WeakSet()
const native = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")
let messages = null

function eligible(input) {
  const max = input.getAttribute("max")
  return max === null || max === "" || Number(max) >= 1000
}

function decimalsOf(step) {
  if (!step || !step.includes(".")) return step ? 0 : 2
  return step.split(".")[1].length
}

// "12345.6" → "12,345.6"; keeps what is being typed ("12,345." stays).
function format(raw) {
  if (raw === "" || raw === "-") return raw
  const negative = raw.startsWith("-")
  const [whole, fraction] = raw.replace("-", "").split(".")
  const grouped = whole.replace(/^0+(?=\d)/, "").replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  return (negative ? "-" : "") + grouped + (fraction === undefined ? "" : `.${fraction}`)
}

// What the user typed, as a plain number: digits, one point, a minus first
// (only where the field allows below zero) and no more decimals than its step.
function clean(text, input) {
  const negative = input.dataset.thousandsNegative === "true" && text.trim().startsWith("-")
  let [whole, ...rest] = String(text).replace(/[^\d.]/g, "").split(".")
  let raw = whole
  if (rest.length) raw += `.${rest.join("").slice(0, Number(input.dataset.thousandsDecimals))}`
  return (negative ? "-" : "") + raw
}

function readMessages() {
  if (messages) return messages
  try {
    messages = JSON.parse(document.querySelector("meta[name=thousands-messages]")?.content || "{}")
  } catch {
    messages = {}
  }
  return messages
}

function validate(input) {
  const raw = input.value
  const number = Number(raw)
  const { thousandsMin: min, thousandsMax: max } = input.dataset
  let message = ""
  if (raw !== "" && raw !== "-" && !Number.isNaN(number)) {
    if (min !== undefined && min !== "" && number < Number(min)) message = (readMessages().min || "").replace("%{min}", format(min))
    else if (max !== undefined && max !== "" && number > Number(max)) message = (readMessages().max || "").replace("%{max}", format(max))
  } else if (raw === "-") {
    message = readMessages().number || ""
  }
  // A message of the field's own (data-invalid-message) goes first.
  input.setCustomValidity(message && (input.dataset.invalidMessage || message))
}

function enhance(input) {
  if (enhanced.has(input)) {
    if (input.type === "number") input.type = "text"
    return
  }
  // A copy of an enhanced field (Turbo's cache) keeps its marks, not its value.
  if (!input.dataset.thousands) {
    if (!eligible(input)) return

    const min = input.getAttribute("min")
    input.dataset.thousands = "true"
    input.dataset.thousandsMin = min ?? ""
    input.dataset.thousandsMax = input.getAttribute("max") ?? ""
    input.dataset.thousandsDecimals = decimalsOf(input.getAttribute("step"))
    input.dataset.thousandsNegative = String(min === null || Number(min) < 0)
    // A live refresh (morph) would turn it back into a number field.
    input.dataset.liveKeep = [ input.dataset.liveKeep, "type" ].filter(Boolean).join(" ")
  }
  enhanced.add(input)
  const current = native.get.call(input)
  input.type = "text"
  input.autocomplete = "off"

  Object.defineProperty(input, "value", {
    configurable: true,
    get() { return native.get.call(this).replace(/,/g, "") },
    set(value) { native.set.call(this, format(clean(value ?? "", this))) }
  })
  input.value = current
  input.addEventListener("input", typed)
  input.addEventListener("change", () => validate(input))
}

// Formats while typing and keeps the caret after the same digit.
function typed(event) {
  const input = event.target
  const shown = native.get.call(input)
  const caret = input.selectionStart ?? shown.length
  const before = shown.slice(0, caret).replace(/[^\d.-]/g, "").length
  const formatted = format(clean(shown, input))
  if (formatted !== shown) {
    native.set.call(input, formatted)
    let position = 0
    for (let seen = 0; position < formatted.length && seen < before; position++) {
      if (formatted[position] !== ",") seen++
    }
    input.setSelectionRange(position, position)
  }
  validate(input)
}

function enhanceWithin(root) {
  if (root.matches?.(SELECTOR)) enhance(root)
  root.querySelectorAll?.(SELECTOR).forEach(enhance)
}

// The form sends the plain number.
document.addEventListener("formdata", (event) => {
  const names = new Set([ ...event.target.querySelectorAll("input[data-thousands]") ].map((input) => input.name).filter(Boolean))
  names.forEach((name) => {
    const values = event.formData.getAll(name)
    event.formData.delete(name)
    values.forEach((value) => event.formData.append(name, typeof value === "string" ? value.replace(/,/g, "") : value))
  })
}, true)

enhanceWithin(document.documentElement)
new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    if (mutation.type === "attributes") enhanceWithin(mutation.target)
    else mutation.addedNodes.forEach((node) => node.nodeType === Node.ELEMENT_NODE && enhanceWithin(node))
  })
}).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: [ "type" ] })
