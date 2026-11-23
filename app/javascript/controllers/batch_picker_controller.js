import { Controller } from "@hotwired/stimulus"

// The lots a shipment or a process takes (Fernando, 2026-11-13; processes,
// 2026-11-16): only the free lots of the coffee state and warehouse chosen
// in the form show (one of another is unmarked); «Nuevo lote» opens with
// them; a lot made in the window ("coffee_batch:created") joins the list
// marked. With a `total` target (a process), it holds the gross pounds of
// the marked lots, and of the invoices marked in «¿Qué café lleva?»
// (shipment_coffee_controller.js, Fernando 2026-11-22).
export default class extends Controller {
  static targets = ["list", "item", "empty", "newLink", "total"]
  static values = { newUrl: String, scope: { type: String, default: "shipment" }, stateField: { type: String, default: "coffee_state" } }

  connect() {
    this.form = this.element.closest("form")
    this.onChange = (event) => {
      if (event.target.matches(`[name='${this.scopeValue}[${this.stateFieldValue}]'], [name='${this.scopeValue}[warehouse_id]']`)) this.filter()
      if (event.target.matches(`[name='${this.scopeValue}[batch_ids][]']`)) this.sum()
    }
    this.onInvoices = () => this.sum()
    this.form?.addEventListener("change", this.onChange)
    this.form?.addEventListener("shipment-coffee:summed", this.onInvoices)
    this.filter()
  }

  disconnect() {
    this.form?.removeEventListener("change", this.onChange)
    this.form?.removeEventListener("shipment-coffee:summed", this.onInvoices)
  }

  current() {
    const states = [ ...(this.form?.querySelectorAll(`[name='${this.scopeValue}[${this.stateFieldValue}]']`) || []) ]
    const state = states.find((field) => field.type !== "radio" || field.checked)
    return {
      state: state?.value || "",
      warehouse: this.form?.querySelector(`[name='${this.scopeValue}[warehouse_id]']`)?.value || ""
    }
  }

  // The gross pounds of the marked lots, into the process's field.
  sum() {
    if (!this.hasTotalTarget) return

    const marked = this.itemTargets.filter((item) => item.querySelector("input[type=checkbox]")?.checked)
    const invoices = this.invoicesController()?.invoiceShares() || { gross: 0, net: 0 }
    const gross = marked.reduce((total, item) => total + (parseFloat(item.dataset.gross) || 0), invoices.gross)
    const net = marked.reduce((total, item) => total + (parseFloat(item.dataset.net) || 0), invoices.net)
    const value = gross > 0 ? (Math.round(gross * 100) / 100).toFixed(2) : ""
    const netValue = net > 0 ? String(net) : ""
    // Only when it changed: the invoices' picker listens to this field too.
    if (this.totalTarget.value === value && (this.totalTarget.dataset.net || "") === netValue) return
    this.totalTarget.value = value
    this.totalTarget.dataset.net = netValue
    this.totalTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  invoicesController() {
    const element = this.form?.querySelector("[data-controller~='shipment-coffee']")
    return element && this.application.getControllerForElementAndIdentifier(element, "shipment-coffee")
  }

  filter() {
    const { state, warehouse } = this.current()
    let shown = 0
    this.itemTargets.forEach((item) => {
      const fits = item.dataset.coffeeState === state && item.dataset.warehouseId === warehouse
      item.hidden = !fits
      const box = item.querySelector("input[type=checkbox]")
      if (!fits) box.checked = false
      box.disabled = !fits
      if (fits) shown += 1
    })
    this.emptyTarget.hidden = shown > 0
    this.sum()
    if (this.hasNewLinkTarget) {
      const url = new URL(this.newUrlValue, window.location.origin)
      url.searchParams.set("coffee_state", state)
      url.searchParams.set("warehouse_id", warehouse)
      this.newLinkTarget.href = url.pathname + url.search
    }
  }

  add({ detail: { id, label, coffee_state: state, warehouse_id: warehouse, gross, net, gross_value: grossValue, net_value: netValue } }) {
    const item = document.createElement("li")
    item.dataset.batchPickerTarget = "item"
    item.dataset.coffeeState = state
    item.dataset.warehouseId = String(warehouse)
    item.dataset.gross = String(grossValue ?? String(gross).replace(/,/g, ""))
    item.dataset.net = String(netValue ?? String(net).replace(/,/g, ""))
    const box = document.createElement("input")
    box.type = "checkbox"
    box.name = `${this.scopeValue}[batch_ids][]`
    box.value = String(id)
    box.checked = true
    box.className = "mt-1 size-4 accent-primary"
    const text = document.createElement("span")
    text.className = "min-w-0 text-sm"
    const name = document.createElement("span")
    name.className = "block font-medium"
    name.textContent = label
    const pounds = document.createElement("span")
    pounds.className = "block text-xs text-ink-muted"
    pounds.textContent = this.element.dataset.poundsLabel?.replace("%{gross}", gross).replace("%{net}", net) || `${gross} / ${net}`
    text.append(name, pounds)
    const card = document.createElement("label")
    card.className = "data-card flex cursor-pointer items-start gap-3"
    card.append(box, text)
    item.append(card)
    this.listTarget.prepend(item)
    this.filter()
    box.checked = !box.disabled
    box.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
