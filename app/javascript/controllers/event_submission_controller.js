import { Controller } from "@hotwired/stimulus"

// Drives the inline "Add an event" panel on a totem board: opens the panel and
// reveals the recurrence cadence toggle when "happens regularly" is checked.
export default class extends Controller {
  static targets = ["panel", "cta", "cadence", "recurring"]

  open(event) {
    event.preventDefault()
    if (this.hasPanelTarget) {
      this.panelTarget.hidden = false
      this.panelTarget.scrollIntoView({ behavior: "smooth", block: "start" })
      const first = this.panelTarget.querySelector("input, textarea")
      if (first) first.focus()
    }
    this.ctaTargets.forEach((el) => (el.hidden = true))
  }

  toggleCadence() {
    if (!this.hasCadenceTarget) return
    this.cadenceTarget.classList.toggle("hidden", !this.recurringTarget.checked)
  }
}
