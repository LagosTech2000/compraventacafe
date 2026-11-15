import { Controller } from "@hotwired/stimulus"

// Waiting for the reader while a finger is registered (Fernando,
// 2026-11-14): the bridge of this PC asks for the finger three times
// (FingerprintEnrollment); each step, the end or a failure arrive as
// "fingerprint:enroll" events (fingerprint.js). Saved, it goes back to the
// person's page; without news in `timeout` seconds, it says so.
export default class extends Controller {
  static targets = ["step", "message", "retry"]
  static values = { requestId: String, doneUrl: String, timeout: { type: Number, default: 120 }, texts: Object }

  connect() {
    window.addEventListener("fingerprint:enroll", this.receive)
    this.timer = setTimeout(() => this.fail(this.textsValue.timeout), this.timeoutValue * 1000)
    this.show(0)
  }

  disconnect() {
    window.removeEventListener("fingerprint:enroll", this.receive)
    clearTimeout(this.timer)
  }

  receive = ({ detail }) => {
    if (detail.request_id !== this.requestIdValue) return

    clearTimeout(this.timer)
    if (detail.type === "enroll_progress") {
      this.show(detail.step)
      this.timer = setTimeout(() => this.fail(this.textsValue.timeout), this.timeoutValue * 1000)
    } else if (detail.type === "enrolled") {
      this.messageTarget.textContent = this.textsValue.done
      this.element.dataset.state = "done"
      window.Turbo.visit(this.doneUrlValue)
    } else if (detail.type === "enroll_failed") {
      this.fail(detail.message)
    }
  }

  show(step) {
    this.stepTargets.forEach((element, index) => element.classList.toggle("is-done", index < step))
    this.messageTarget.textContent = step >= this.stepTargets.length ? this.textsValue.saving : this.textsValue.put.replace("%{n}", step + 1)
  }

  fail(message) {
    this.element.dataset.state = "failed"
    this.messageTarget.textContent = message
    this.retryTarget.hidden = false
  }
}
