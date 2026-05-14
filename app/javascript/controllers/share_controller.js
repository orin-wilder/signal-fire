import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, title: String, eventId: Number }

  async share() {
    if (navigator.share) {
      await navigator.share({ title: this.titleValue, url: this.urlValue })
      this.#track()
    } else {
      await navigator.clipboard.writeText(this.urlValue)
      this.#showToast("Link copied")
      this.#track()
    }
  }

  #track() {
    fetch("/analytics/track", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content,
      },
      body: JSON.stringify({ event: "event_shared", event_id: this.eventIdValue }),
    })
  }

  #showToast(msg) {
    const toast = document.createElement("div")
    toast.textContent = msg
    toast.style.cssText = [
      "position:fixed", "bottom:5rem", "left:50%", "transform:translateX(-50%)",
      "background:#1a1a12", "color:#f2f0d9", "padding:0.5rem 1.25rem",
      "border-radius:9999px", "font-size:0.875rem", "z-index:9999",
      "pointer-events:none",
    ].join(";")
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 2200)
  }
}
