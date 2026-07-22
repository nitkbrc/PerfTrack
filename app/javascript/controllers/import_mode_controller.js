import { Controller } from "@hotwired/stimulus"

// Shows one import panel (manual or CSV) at a time. Pair with segmented-switch
// via segmented-switch:change->import-mode#select (detail.value = mode).
export default class extends Controller {
  static targets = [ "panel" ]
  static values = { mode: { type: String, default: "manual" } }

  connect() {
    this.apply()
  }

  select(event) {
    const mode = event.detail?.value ?? event.currentTarget?.dataset?.mode
    // Ignore nested switches (e.g. Admin/Faculty/Student) that also dispatch
    // segmented-switch:change with unrelated values.
    if (mode !== "manual" && mode !== "csv") return

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
