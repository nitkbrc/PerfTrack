import { Controller } from "@hotwired/stimulus"

// Multi-step create wizard for Division / SubDivision (name → hierarchy → assign → done).
export default class extends Controller {
  static targets = ["step", "progressStep", "progressConnector"]
  static values = { step: { type: Number, default: 1 }, total: { type: Number, default: 3 } }

  connect() {
    this.showStep(this.stepValue)
  }

  next(event) {
    event.preventDefault()
    if (!this.validateCurrent()) return
    if (this.stepValue < this.totalValue) {
      this.stepValue += 1
      this.showStep(this.stepValue)
    }
  }

  back(event) {
    event.preventDefault()
    if (this.stepValue > 1) {
      this.stepValue -= 1
      this.showStep(this.stepValue)
    }
  }

  selectHierarchy(event) {
    const id = event.currentTarget.dataset.hierarchyId
    const input = this.element.querySelector("[data-hierarchy-id-field]")
    if (input) input.value = id
    this.element.querySelectorAll("[data-hierarchy-option]").forEach((el) => {
      el.classList.toggle("ring-2", el.dataset.hierarchyId === id)
      el.classList.toggle("ring-primary", el.dataset.hierarchyId === id)
    })
    this.refreshAssignmentFields(event.currentTarget)
  }

  refreshAssignmentFields(optionEl) {
    const container = this.element.querySelector("[data-assignment-fields]")
    if (!container || !optionEl) return
    const roles = JSON.parse(optionEl.dataset.roles || "[]")
    container.innerHTML = roles.map((role) => `
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">${role.name}</label>
        <select name="assignments[${role.id}]" required class="block w-full rounded-lg border border-slate-200 px-3 py-2 text-sm">
          <option value="">Select faculty…</option>
          ${(role.eligible || []).map((u) => `<option value="${u.id}">${u.label}</option>`).join("")}
        </select>
      </div>
    `).join("")
  }

  validateCurrent() {
    const panel = this.stepTargets.find((el) => !el.classList.contains("hidden"))
    if (!panel) return true

    if (this.stepValue === 1) {
      const name = panel.querySelector("[name*='[name]']")
      if (name && !name.value.trim()) {
        alert("Name is required.")
        return false
      }
      return true
    }

    if (this.stepValue === 2) {
      const field = this.element.querySelector("[data-hierarchy-id-field]")
      if (!field?.value) {
        alert("Choose a hierarchy.")
        return false
      }
      return true
    }

    if (this.stepValue === 3) {
      const selects = [...panel.querySelectorAll("select[name^='assignments']")]
      if (selects.some((s) => !s.value)) {
        alert("Assign a person to every role.")
        return false
      }
      return true
    }

    return true
  }

  showStep(n) {
    this.stepTargets.forEach((el) => {
      el.classList.toggle("hidden", Number(el.dataset.step) !== n)
    })
    this.progressStepTargets.forEach((el, index) => {
      const stepNum = index + 1
      el.classList.toggle("opacity-40", stepNum > n)
      el.classList.toggle("font-semibold", stepNum === n)
    })
  }
}
