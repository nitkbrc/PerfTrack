import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "button" ]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    const showing = !this.panelTarget.classList.contains("hidden")
    this.buttonTarget.textContent = showing ? "Hide history" : "View history"
  }
}
