import { Controller } from "@hotwired/stimulus"

// Optimistic, reviewable AI assist for the event description.
// Mirrors totem_favorite_controller's fetch + DOM-update idiom. Every change is
// reversible (Undo) and nothing is saved until the host submits the form.
export default class extends Controller {
  static targets = ["description", "short", "enhanceBtn", "summarizeBtn", "status"]
  static values = { enhanceUrl: String, summarizeUrl: String }

  enhance() {
    this.#run({
      url: this.enhanceUrlValue,
      target: this.descriptionTarget,
      pending: "Enhancing…",
      done: "Enhanced"
    })
  }

  summarize() {
    this.#run({
      url: this.summarizeUrlValue,
      target: this.hasShortTarget ? this.shortTarget : this.descriptionTarget,
      pending: "Summarizing…",
      done: "Short version added"
    })
  }

  async #run({ url, target, pending, done }) {
    const text = this.descriptionTarget.value.trim()
    if (!text) { this.#status("Write a description first."); return }

    const previous = target.value
    this.#busy(true)
    this.#status(pending)

    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken() },
        body: JSON.stringify({ text })
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        this.#status(data.error || "Couldn't do that. Try again.")
        return
      }
      target.value = data.text
      this.#offerUndo(target, previous, done)
    } catch {
      this.#status("Network error. Try again.")
    } finally {
      this.#busy(false)
    }
  }

  #offerUndo(target, previous, done) {
    this.statusTarget.textContent = `${done} · `
    const undo = document.createElement("button")
    undo.type = "button"
    undo.textContent = "Undo"
    undo.className = "underline text-ink cursor-pointer"
    undo.addEventListener("click", () => {
      target.value = previous
      this.#status("Reverted.")
    })
    this.statusTarget.appendChild(undo)
  }

  #busy(isBusy) {
    [this.enhanceBtnTarget, this.summarizeBtnTarget].forEach((b) => { b.disabled = isBusy })
  }

  // Status copy is always stone/ink — ember is reserved for live states only.
  #status(text) {
    this.statusTarget.textContent = text
  }
}

function csrfToken() {
  return document.querySelector("meta[name=csrf-token]")?.content ?? ""
}
