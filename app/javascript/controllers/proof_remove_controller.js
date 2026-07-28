import { Controller } from "@hotwired/stimulus"

// Immediately removes an already-saved proof thumbnail via DELETE.
export default class extends Controller {
  static values = {
    url: String,
    proofId: String
  }

  async remove(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    if (button.disabled) return
    button.disabled = true

    try {
      const response = await fetch(this.urlValue, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.#csrfToken()
        },
        credentials: "same-origin"
      })

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}))
        throw new Error(payload.error || "Could not remove proof.")
      }

      this.element.remove()
    } catch (error) {
      button.disabled = false
      window.alert(error.message)
    }
  }

  #csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
