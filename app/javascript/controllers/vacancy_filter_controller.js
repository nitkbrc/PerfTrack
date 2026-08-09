import { Controller } from "@hotwired/stimulus"

// Hides filled slots and branches that have no vacancies when active.
export default class extends Controller {
  static targets = [ "slot", "branch", "toggle", "label" ]

  connect() {
    this._onlyVacancies = false
  }

  toggle() {
    this._onlyVacancies = !this._onlyVacancies
    this.apply()
  }

  apply() {
    const only = this._onlyVacancies

    this.slotTargets.forEach((slot) => {
      const vacant = slot.dataset.vacant === "true"
      slot.classList.toggle("hidden", only && !vacant)
    })

    this.branchTargets.forEach((branch) => {
      const vacantCount = Number(branch.dataset.vacantCount || 0)
      const noTemplate = branch.dataset.noTemplate === "true"
      const hide = only && vacantCount === 0 && !noTemplate
      branch.classList.toggle("hidden", hide)
      if (only && vacantCount > 0) {
        const details = branch.querySelector("details[data-tree-target='node']")
        if (details) details.open = true
      }
    })

    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-pressed", only ? "true" : "false")
      this.toggleTarget.classList.toggle("bg-primary", only)
      this.toggleTarget.classList.toggle("text-white", only)
      this.toggleTarget.classList.toggle("border-primary", only)
      this.toggleTarget.classList.toggle("bg-white", !only)
      this.toggleTarget.classList.toggle("text-slate-700", !only)
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = only ? "Showing vacancies" : "Only vacancies"
    }
  }
}
