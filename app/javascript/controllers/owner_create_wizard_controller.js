import { Controller } from "@hotwired/stimulus"

// Multi-step create wizard for Division / SubDivision (details → hierarchy → assign).
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

  selectDivType(event) {
    const type = event.currentTarget.dataset.divType
    const field = this.element.querySelector("[data-div-type-field]")
    if (field) field.value = type

    this.element.querySelectorAll("[data-div-type-option]").forEach((el) => {
      const selected = el.dataset.divType === type
      el.classList.toggle("is-selected", selected)
      el.setAttribute("aria-pressed", selected ? "true" : "false")
    })
  }

  selectHierarchy(event) {
    const id = event.currentTarget.dataset.hierarchyId
    const input = this.element.querySelector("[data-hierarchy-id-field]")
    if (input) input.value = id
    this.element.querySelectorAll("[data-hierarchy-option]").forEach((el) => {
      const selected = el.dataset.hierarchyId === id
      el.classList.toggle("is-selected", selected)
      el.setAttribute("aria-pressed", selected ? "true" : "false")
    })
    this.refreshAssignmentFields(event.currentTarget)
  }

  refreshAssignmentFields(optionEl) {
    const container = this.element.querySelector("[data-assignment-fields]")
    if (!container || !optionEl) return
    const roles = JSON.parse(optionEl.dataset.roles || "[]")
    container.innerHTML = roles.map((role) => `
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">${this.escapeHtml(role.name)}</label>
        <select name="assignments[${role.id}]" required
                class="mt-1 block h-10 w-full rounded-md border border-border-subtle bg-surface-white px-3 py-2 text-sm text-text-main shadow-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-secondary-container/40">
          <option value="">Select faculty…</option>
          ${(role.eligible || []).map((u) =>
            `<option value="${u.id}">${this.escapeHtml(u.label)}</option>`
          ).join("")}
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
        name.focus()
        return false
      }
      const division = panel.querySelector("[name*='[division_id]']")
      if (division && !division.value) {
        alert("Choose a parent division.")
        division.focus()
        return false
      }
      const divType = this.element.querySelector("[data-div-type-field]")
      if (divType && !divType.value) {
        alert("Choose a division type.")
        return false
      }
      return true
    }

    if (this.stepValue === 2) {
      const field = this.element.querySelector("[data-hierarchy-id-field]")
      if (!field?.value) {
        alert("Choose a hierarchy template.")
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
    this.updateProgress(n)
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  updateProgress(n) {
    const COMPLETED = "#16a34a"
    const ACTIVE = "#2563eb"
    const UPCOMING_BG = "#ffffff"
    const UPCOMING_TEXT = "#94a3b8"

    this.progressStepTargets.forEach((stepEl, i) => {
      const step = i + 1
      const icon = stepEl.querySelector("[data-progress-icon]")
      const number = stepEl.querySelector("[data-progress-number]")
      const check = stepEl.querySelector("[data-progress-check]")
      const label = stepEl.querySelector("[data-progress-label]")
      if (!icon || !number || !check || !label) return

      const completed = step < n
      const active = step === n

      icon.classList.toggle("border-transparent", completed || active)
      icon.classList.toggle("text-white", completed || active)
      icon.classList.toggle("border-slate-200", !completed && !active)
      icon.classList.toggle("text-slate-400", !completed && !active)

      icon.style.backgroundColor = completed ? COMPLETED : active ? ACTIVE : UPCOMING_BG
      label.style.color = completed ? COMPLETED : active ? ACTIVE : UPCOMING_TEXT

      number.classList.toggle("hidden", completed)
      check.classList.toggle("hidden", !completed)
      if (completed) {
        number.setAttribute("aria-hidden", "true")
        check.removeAttribute("aria-hidden")
      } else {
        number.removeAttribute("aria-hidden")
        check.setAttribute("aria-hidden", "true")
      }
    })

    if (this.hasProgressConnectorTarget) {
      this.progressConnectorTargets.forEach((connector, i) => {
        // Connectors sit between steps: index 0 is between 1–2, etc.
        const betweenCompleted = i + 1 < n
        connector.classList.toggle("bg-green-600", betweenCompleted)
        connector.classList.toggle("bg-slate-200", !betweenCompleted)
      })
    }
  }

  escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
  }
}
