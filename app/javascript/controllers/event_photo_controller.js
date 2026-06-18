import { Controller } from "@hotwired/stimulus"

// "Add from a photo": reads an event off a flyer/poster image and prefills the
// submission form. Sends the image as a base64 data URL to the from_photo
// endpoint — nothing is uploaded or stored; the user reviews the prefilled
// fields before submitting through the normal create path.
export default class extends Controller {
  static targets = ["input", "status"]
  static values = { url: String }

  choose() {
    this.inputTarget.click()
  }

  async upload() {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.setStatus("Reading photo…", false)
    let dataUrl
    try {
      dataUrl = await this.readAsDataURL(file)
    } catch {
      this.setStatus("Couldn't read that file.", true)
      return
    }

    try {
      const res = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken(),
          Accept: "application/json",
        },
        body: JSON.stringify({ image: dataUrl }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        this.setStatus(data.error || "Couldn't read that photo.", true)
        return
      }
      this.fill(data.event || {})
      this.setStatus("Filled in what we could read — give it a look.", false)
    } catch {
      this.setStatus("Something went wrong. Try again.", true)
    } finally {
      this.inputTarget.value = ""
    }
  }

  fill(event) {
    this.set("event[title]", event.title)
    this.set("event[date]", event.date)
    this.set("event[time]", event.time)
    this.set("event[short_description]", event.description)
  }

  set(name, value) {
    if (!value) return
    const field = this.element.closest("form")?.querySelector(`[name="${name}"]`)
    if (field) field.value = value
  }

  readAsDataURL(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => resolve(reader.result)
      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  setStatus(msg, isError) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = msg
    this.statusTarget.classList.toggle("text-ember", isError)
  }
}
