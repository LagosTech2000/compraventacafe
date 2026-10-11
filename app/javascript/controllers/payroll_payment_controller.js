import { Controller } from "@hotwired/stimulus"

// Paying a payroll period: what goes to each member's loans comes off their
// pay. Shows each member's net pay and the totals, refuses (in the browser)
// to take more than the pay, and "Saldar" fills a loan with what it owes or
// what is left of the pay. The server checks it all.
export default class extends Controller {
  static targets = ["line", "amount", "lineLoans", "lineNet", "loansTotal", "netTotal"]
  static values = { overMessage: String }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  fill(event) {
    const input = document.getElementById(event.currentTarget.dataset.targetId)
    const line = input.closest("[data-payroll-payment-target~='line']")
    input.value = ""
    const room = parseFloat(line.dataset.gross) - this.loans(line)
    const amount = this.round(Math.min(parseFloat(event.currentTarget.dataset.owed), Math.max(room, 0)))
    input.value = amount > 0 ? amount.toFixed(2) : ""
    this.update()
  }

  update() {
    let loansTotal = 0
    let netTotal = 0
    this.lineTargets.forEach((line, index) => {
      const gross = parseFloat(line.dataset.gross)
      const loans = this.round(this.loans(line))
      const over = loans > gross
      line.querySelectorAll("input").forEach((input) => input.setCustomValidity(over ? this.overMessageValue : ""))
      this.lineLoansTargets[index].textContent = loans > 0 ? `− L ${this.money.format(loans)}` : "—"
      this.lineNetTargets[index].textContent = `L ${this.money.format(this.round(gross - loans))}`
      loansTotal += loans
      netTotal += gross - loans
    })
    this.loansTotalTarget.textContent = `L ${this.money.format(this.round(loansTotal))}`
    this.netTotalTarget.textContent = `L ${this.money.format(this.round(netTotal))}`
  }

  loans(line) {
    return [...line.querySelectorAll("[data-payroll-payment-target~='amount']")]
      .reduce((sum, input) => sum + (parseFloat(input.value) || 0), 0)
  }

  round(value) {
    return Math.round(value * 100) / 100
  }
}
