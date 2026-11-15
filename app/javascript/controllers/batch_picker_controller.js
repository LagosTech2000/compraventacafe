import { Controller } from "@hotwired/stimulus"

// The lots a shipment takes (Fernando, 2026-11-13): only the free lots of
// the coffee state and warehouse chosen in the form show (one of another
// is unmarked); «Nuevo lote» opens with them; a lot made in the window
// ("coffee_batch:created") joins the list marked.
export default class extends Controller {
  static targets = ["list", "item", "empty", "newLink"]
  static values = { newUrl: String }

  connect() {
    this.form = this.element.closest("form")
    this.onChange = (event) => {
      if (event.target.matches("[name='shipment[coffee_state]'], [name='shipment[warehouse_id]']")) this.filter()
    }
    this.form?.addEventListener("change", this.onChange)
    this.filter()
  }

  disconnect() {
    this.form?.removeEventListener("change", this.onChange)
  }

  current() {
    return {
      state: this.form?.querySelector("[name='shipment[coffee_state]']")?.value || "",
      warehouse: this.form?.querySelector("[name='shipment[warehouse_id]']")?.value || ""
    }
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
    if (this.hasNewLinkTarget) {
      const url = new URL(this.newUrlValue, window.location.origin)
      url.searchParams.set("coffee_state", state)
      url.searchParams.set("warehouse_id", warehouse)
      this.newLinkTarget.href = url.pathname + url.search
    }
  }

  add({ detail: { id, label, coffee_state: state, warehouse_id: warehouse, gross, net } }) {
    const item = document.createElement("li")
    item.dataset.batchPickerTarget = "item"
    item.dataset.coffeeState = state
    item.dataset.warehouseId = String(warehouse)
    const box = document.createElement("input")
    box.type = "checkbox"
    box.name = "shipment[batch_ids][]"
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
