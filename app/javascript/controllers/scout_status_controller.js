import { Controller } from "@hotwired/stimulus"

// Polls the scout run's status while it's pending; reloads the page once the
// background job finishes (complete or failed) so the review queue renders.
export default class extends Controller {
  static values = { url: String, state: String }

  connect() {
    if (this.stateValue === "pending") this.#schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  #schedule() {
    this.timer = setTimeout(() => this.#check(), 3000)
  }

  async #check() {
    try {
      const res = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      const data = await res.json()
      if (data.status && data.status !== "pending") {
        window.location.reload()
        return
      }
    } catch {
      // transient — keep polling
    }
    this.#schedule()
  }
}
