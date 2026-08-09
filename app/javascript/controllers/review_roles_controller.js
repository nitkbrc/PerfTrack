import { Controller } from "@hotwired/stimulus"

// Stages raise-on-behalf toggles on the review roles index and saves them in one bulk POST.
export default class extends Controller {
  static targets = ["form"]

  connect() {
    this._saving = false
    this.onSnapshotRequest = () => this.publishSnapshot({ seedInitial: true })
    this.onSaveRequest = () => {
      this._saving = false
      this.save(new Event("submit"))
    }
    this.onSubmitEnd = () => {
      this._saving = false
    }
    this.element.addEventListener("unsaved-changes:request-snapshot", this.onSnapshotRequest)
    this.element.addEventListener("unsaved-changes:save", this.onSaveRequest)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
    this.publishSnapshot({ seedInitial: true })
  }

  disconnect() {
    this.element.removeEventListener("unsaved-changes:request-snapshot", this.onSnapshotRequest)
    this.element.removeEventListener("unsaved-changes:save", this.onSaveRequest)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  toggleChanged(event) {
    const checkbox = event.currentTarget
    this.syncStatusLabel(checkbox)
    this.publishSnapshot()
  }

  syncStatusLabel(checkbox) {
    const label = checkbox.closest("label")?.querySelector("[data-raiseable-status]")
    if (!label) return

    const on = checkbox.checked
    label.textContent = on ? "On" : "Off"
    label.classList.toggle("text-slate-700", on)
    label.classList.toggle("text-slate-400", !on)
  }

  publishSnapshot({ seedInitial = false } = {}) {
    const roles = {}
    this.element.querySelectorAll("input[data-raiseable-toggle]").forEach((checkbox) => {
      roles[checkbox.dataset.roleId] = checkbox.checked ? "1" : "0"
    })
    const snapshot = JSON.stringify(roles)
    this.element.dispatchEvent(new CustomEvent("unsaved-changes:snapshot", {
      bubbles: true,
      detail: { snapshot, seedInitial }
    }))
  }

  save(event) {
    event.preventDefault()
    if (this._saving) return

    this._saving = true
    this.publishSnapshot({ seedInitial: true })

    const form = this.formTarget
    form.querySelectorAll("input[data-bulk-role-field]").forEach((input) => input.remove())

    this.element.querySelectorAll("input[data-raiseable-toggle]").forEach((checkbox) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = `roles[${checkbox.dataset.roleId}][raiseable_on_behalf_eligible]`
      input.value = checkbox.checked ? "1" : "0"
      input.dataset.bulkRoleField = "true"
      form.appendChild(input)
    })

    form.requestSubmit()
  }
}
