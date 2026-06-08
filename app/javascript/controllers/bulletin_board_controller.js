import { Controller } from "@hotwired/stimulus"

// Drives the standalone bulletin board: expands the inline submit panel and
// reveals the recurrence cadence toggle when "happens regularly" is checked.
export default class extends Controller {
  static targets = ["panel", "cta", "cadence", "recurring"]

  open(event) {
    event.preventDefault()
    this.panelTarget.hidden = false
    this.ctaTargets.forEach((el) => (el.hidden = true))
    this.panelTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    const first = this.panelTarget.querySelector("input, textarea")
    if (first) first.focus()
  }

  toggleCadence() {
    if (!this.hasCadenceTarget) return
    this.cadenceTarget.hidden = !this.recurringTarget.checked
  }
}
