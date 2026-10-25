import { Controller } from "@hotwired/stimulus"

// Paying a period of the Planilla interna: the totals as a preview while
// typing (StaffPaymentIssuer calculates them again on save).
//
//   gross = salary (monthly ÷ 30 × days, fixed here) + overtime hours × the role's hour rate
//           + the bonuses of the goals marked met + the free bonus
//   net   = gross − the advances of the period
//
// A free bonus asks for its reason before sending.
export default class extends Controller {
  static targets = ["salary", "hours", "goal", "extraBonus", "extraReason",
                    "salaryTotal", "overtime", "bonuses", "gross", "net", "negative"]
  static values = { rate: Number, advances: Number }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const salary = this.number(this.salaryTarget.dataset.amount)
    const overtime = this.round(this.number(this.hasHoursTarget ? this.hoursTarget.value : "") * this.rateValue)
    const goals = this.goalTargets.filter((box) => box.checked).reduce((sum, box) => sum + parseFloat(box.dataset.bonus), 0)
    const extra = this.number(this.extraBonusTarget.value)
    const gross = this.round(salary + overtime + goals + extra)
    const net = this.round(gross - this.advancesValue)

    this.salaryTotalTarget.textContent = this.format(salary)
    this.overtimeTarget.textContent = this.format(overtime)
    this.bonusesTarget.textContent = this.format(goals + extra)
    this.grossTarget.textContent = this.format(gross)
    this.netTarget.textContent = this.format(net)
    this.negativeTarget.hidden = net >= 0
    this.extraReasonTarget.required = extra > 0
  }

  number(value) {
    const parsed = parseFloat(value)
    return parsed > 0 ? parsed : 0
  }

  round(value) {
    return Math.round(value * 100) / 100
  }

  format(value) {
    return `${value < 0 ? "−" : ""}L ${this.money.format(Math.abs(value))}`
  }
}
