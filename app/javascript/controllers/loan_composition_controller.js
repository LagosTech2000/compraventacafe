import { Controller } from "@hotwired/stimulus"

// What a loan lends: cash plus supply lines (fertilizer sacks...). Adds and
// removes lines from a <template>, fills a line's price from the supply's
// default (editable), and shows each line's total, the supplies total, the
// principal (cash + supplies) and whether the loan is cash, supplies or
// mixed. Loan (Ruby) computes the same on save; this is only a preview.
//
// A supply created in the modal ("supply:created", wired to #addSupply) is
// added to every line's list and selected in the last empty line.
export default class extends Controller {
  static targets = ["cash", "items", "item", "template", "empty", "supply", "quantity", "price", "unit",
                    "lineTotal", "destroy", "cashTotal", "suppliesTotal", "principal", "kind"]
  static values = { supplies: Object }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
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
    this.suppliesValue = { ...this.suppliesValue, [id]: { name, unit, price } }
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

    this.emptyTarget.hidden = lines > 0
    this.cashTotalTarget.textContent = `L ${this.money.format(cash)}`
    this.suppliesTotalTarget.textContent = `L ${this.money.format(supplies)}`
    this.principalTarget.textContent = `L ${this.money.format(cash + supplies)}`
    this.showKind(lines === 0 ? (cash > 0 ? "cash" : null) : (cash > 0 ? "mixed" : "supplies"))
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
