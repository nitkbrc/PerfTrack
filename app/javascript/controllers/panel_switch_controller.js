import { Controller } from "@hotwired/stimulus"

// Shows one panel at a time based on data-mode. Pair with segmented-switch
// via segmented-switch:change->panel-switch#select (detail.value = mode).
export default class extends Controller {
  static targets = [ "panel" ]
  static values = { mode: String }

  connect() {
    this.apply()
  }

  select(event) {
    const mode = event.detail?.value ?? event.currentTarget?.dataset?.mode
    if (!mode) return
    if (!this.panelTargets.some((panel) => panel.dataset.mode === mode)) return

    this.modeValue = mode
    this.apply()
  }

  apply() {
    const mode = this.modeValue

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.mode === mode
      panel.classList.toggle("hidden", !active)
      panel.setAttribute("aria-hidden", active ? "false" : "true")
    })
  }
}
