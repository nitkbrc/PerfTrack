import { Controller } from "@hotwired/stimulus"

// Two independent segmented switches (polarity × status) show one history panel.
export default class extends Controller {
  static targets = [ "panel" ]
  static values = {
    polarity: { type: String, default: "positive" },
    status: { type: String, default: "accepted" }
  }

  connect() {
    this.apply()
  }

  setPolarity(event) {
    const value = event.detail?.value
    if (!value) return

    this.polarityValue = value
    this.apply()
  }

  setStatus(event) {
    const value = event.detail?.value
    if (!value) return

    this.statusValue = value
    this.apply()
  }

  apply() {
    const key = `${this.polarityValue}-${this.statusValue}`

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.filter === key
      panel.classList.toggle("hidden", !active)
      panel.setAttribute("aria-hidden", active ? "false" : "true")
    })
  }
}
