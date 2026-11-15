import { Controller } from "@hotwired/stimulus"

// What a loan lends: cash plus supply lines (fertilizer sacks...). Adds and
// removes lines from a <template>, fills a line's price from the supply's
// default (editable), and shows each line's total, the supplies total, the
// principal (cash + supplies) and whether the loan is cash, supplies or
// mixed. Loan (Ruby) computes the same on save; this is only a preview.
//
// A line that lends more than is left to lend of its supply (all its lines
// together) says so: it is lent anyway and stays to be delivered (Fernando,
// 2026-11-13). On editing, what the saved lines lent counts as still there.
//
// A supply created in the modal ("supply:created", wired to #addSupply) is
// added to every line's list and selected in the last empty line.
export default class extends Controller {
  static targets = ["cash", "items", "item", "template", "empty", "supply", "quantity", "price", "unit",
                    "lineTotal", "destroy", "cashTotal", "suppliesTotal", "principal", "kind", "stockWarning"]
  static values = { supplies: Object, noStock: String }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.amount = new Intl.NumberFormat("es-HN", { maximumFractionDigits: 2 })
    this.update()
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, String(Date.now()))
    this.itemsTarget.insertAdjacentHTML("beforeend", html)
    const item = this.itemTargets[this.itemTargets.length - 1]
    this.update()
    item.querySelector("select")?.focus()
    return item
  }

  // A saved line is marked for removal (and hidden); a new one is dropped.
  remove(event) {
    const item = event.target.closest("[data-loan-composition-target~='item']")
    const destroy = item.querySelector("[data-loan-composition-target~='destroy']")
    if (item.querySelector("input[name$='[id]']")) {
      destroy.value = "1"
      item.hidden = true
      item.querySelectorAll("input, select").forEach((field) => { if (field !== destroy) field.disabled = true })
    } else {
      item.remove()
    }
    this.update()
  }

  pickSupply(event) {
    const item = event.target.closest("[data-loan-composition-target~='item']")
    const supply = this.suppliesValue[event.target.value]
    if (supply) {
      this.field(item, "price").value = supply.price
      this.field(item, "unit").textContent = supply.unit
      this.field(item, "quantity").focus()
    }
    this.update()
  }

  addSupply({ detail: { id, name, unit, price } }) {
    this.suppliesValue = { ...this.suppliesValue, [id]: { name, unit, price, available: 0 } }
    const selects = [...this.supplyTargets, this.templateTarget.content.querySelector("select")]
    selects.forEach((select) => select.add(new Option(name, String(id))))

    const visible = this.itemTargets.filter((item) => !item.hidden)
    const emptyLine = visible.find((item) => this.field(item, "supply").value === "")
    const item = emptyLine || this.add()
    const select = this.field(item, "supply")
    select.value = String(id)
    // Called directly: a line just added is not wired to its actions yet.
    this.pickSupply({ target: select })
  }

  update() {
    const cash = this.number(this.cashTarget.value)
    let supplies = 0
    let lines = 0

    this.itemTargets.forEach((item) => {
      if (item.hidden) return
      lines += 1
      const quantity = this.number(this.field(item, "quantity").value)
      const price = this.number(this.field(item, "price").value)
      const total = Math.round(quantity * price * 100) / 100
      supplies += total
      this.field(item, "lineTotal").textContent = quantity > 0 && price > 0 ? `L ${this.money.format(total)}` : "—"
    })

    this.warnStock()
    this.emptyTarget.hidden = lines > 0
    this.cashTotalTarget.textContent = `L ${this.money.format(cash)}`
    this.suppliesTotalTarget.textContent = `L ${this.money.format(supplies)}`
    this.principalTarget.textContent = `L ${this.money.format(cash + supplies)}`
    this.showKind(lines === 0 ? (cash > 0 ? "cash" : null) : (cash > 0 ? "mixed" : "supplies"))
  }

  // Per supply: what its visible lines lend against what is left, plus
  // what its saved lines had lent (they are part of what is lent already).
  warnStock() {
    const wanted = {}
    const room = {}
    this.itemTargets.forEach((item) => {
      if (item.dataset.savedSupply) {
        room[item.dataset.savedSupply] = (room[item.dataset.savedSupply] || 0) + this.number(item.dataset.savedQuantity)
      }
      if (item.hidden) return
      const id = this.field(item, "supply").value
      if (id) wanted[id] = (wanted[id] || 0) + this.number(this.field(item, "quantity").value)
    })

    this.itemTargets.forEach((item) => {
      const warning = this.field(item, "stockWarning")
      if (!warning) return
      const id = this.field(item, "supply").value
      const supply = this.suppliesValue[id]
      const available = supply ? Math.round(((supply.available || 0) + (room[id] || 0)) * 100) / 100 : 0
      const short = !item.hidden && supply && wanted[id] > 0 && wanted[id] > available
      warning.hidden = !short
      if (short) {
        const missing = Math.round((wanted[id] - Math.max(available, 0)) * 100) / 100
        warning.textContent = this.noStockValue
          .replace("%{name}", supply.name).replace(/%\{unit\}/g, supply.unit)
          .replace("%{available}", this.amount.format(available)).replace("%{missing}", this.amount.format(missing))
      }
    })
  }

  showKind(kind) {
    const labels = JSON.parse(this.kindTarget.dataset.labels)
    this.kindTarget.innerHTML = ""
    if (!kind) return (this.kindTarget.textContent = "—")

    const badge = document.createElement("span")
    badge.className = "badge badge-neutral"
    badge.textContent = labels[kind]
    this.kindTarget.append(badge)
  }

  field(item, name) {
    return item.querySelector(`[data-loan-composition-target~='${name}']`)
  }

  number(value) {
    const parsed = parseFloat(value)
    return parsed > 0 ? parsed : 0
  }
}
