import { Controller } from "@hotwired/stimulus"

// Overlay modal for Turbo Frame forms: close via X, backdrop, or Escape.
// On successful submit (redirect), visit the redirect URL so the underlying page refreshes.
export default class extends Controller {
  static values = { returnUrl: String }

  connect() {
    document.body.classList.add("overflow-hidden")
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }

  close() {
    const frame = this.element.closest("turbo-frame#modal")
    const onReturnPage = this.hasReturnUrlValue && this.#samePath(this.returnUrlValue)

    if (frame && onReturnPage) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
      return
    }

    if (this.hasReturnUrlValue) {
      window.Turbo.visit(this.returnUrlValue)
    } else if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }

  submitEnd(event) {
    if (!event.detail.success) return

    const response = event.detail.fetchResponse?.response
    if (response?.redirected) {
      window.Turbo.visit(response.url)
    }
  }

  #samePath(url) {
    try {
      return new URL(url, window.location.origin).pathname === window.location.pathname
    } catch {
      return false
    }
  }
}
