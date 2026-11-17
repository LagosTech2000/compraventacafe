import { Controller } from "@hotwired/stimulus"

// An advance applied to sales by a % of it (Fernando, 2026-11-16): each
// marked row shows the money its percent comes to (all of what is left of
// the advance when it takes the rest) and what the sale still owes after
// it. From an advance ("advance" mode) the percents together never pass
// what is free of it; from a sale ("sale" mode) the amounts together never
// pass what the sale owes. «Aplicar» stays off while none is marked or
// something passes. The server checks it again.
export default class extends Controller {
  static targets = ["row", "summary", "submit"]
  static values = { mode: String, free: Number, due: Number, texts: Object }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  rowTargetConnected() {
    if (this.money) this.update()
  }

  update() {
    let percents = 0
    let amounts = 0
    let marked = 0
    let valid = true

    this.rowTargets.forEach((row) => {
      const box = row.querySelector("input[type=checkbox]")
      const input = row.querySelector("input[name$='[percent]']")
      const amountText = row.querySelector("[data-share-amount]")
      const note = row.querySelector("[data-share-note]")
      const free = parseFloat(row.dataset.free)
      const due = parseFloat(row.dataset.due)
      const percent = parseFloat(input.value)
      input.disabled = !box.checked
      note.classList.remove("text-danger")

      if (!box.checked || !(percent > 0)) {
        amountText.textContent = "—"
        note.textContent = ""
        if (box.checked) valid = false
        return
      }

      marked++
      const amount = percent >= free - 0.00005 ? parseFloat(row.dataset.balance) : Math.round(parseFloat(row.dataset.advanceAmount) * percent) / 100
      amountText.textContent = `L ${this.money.format(amount)}`
      percents += percent
      amounts += amount

      if (percent > free + 0.00005) {
        note.textContent = this.textsValue.over_free.replace("%{percent}", this.percent(free))
        note.classList.add("text-danger")
        valid = false
      } else if (amount > due + 0.005) {
        note.textContent = this.textsValue.over_due.replace("%{due}", `L ${this.money.format(due)}`)
        note.classList.add("text-danger")
        valid = false
      } else {
        note.textContent = this.textsValue.left.replace("%{amount}", `L ${this.money.format(due - amount)}`)
      }
    })

    if (this.modeValue === "advance") {
      if (percents > this.freeValue + 0.00005) valid = false
      this.summaryTarget.textContent = this.textsValue.summary_advance
        .replace("%{percent}", this.percent(percents)).replace("%{amount}", `L ${this.money.format(amounts)}`)
      this.summaryTarget.classList.toggle("text-danger", percents > this.freeValue + 0.00005)
    } else {
      if (amounts > this.dueValue + 0.005) valid = false
      this.summaryTarget.textContent = this.textsValue.summary_sale
        .replace("%{amount}", `L ${this.money.format(amounts)}`).replace("%{due}", `L ${this.money.format(this.dueValue)}`)
      this.summaryTarget.classList.toggle("text-danger", amounts > this.dueValue + 0.005)
    }
    this.submitTarget.disabled = marked === 0 || !valid
  }

  percent(value) {
    return `${(Math.round(value * 10000) / 10000).toLocaleString("en-US", { maximumFractionDigits: 4 })} %`
  }
}
