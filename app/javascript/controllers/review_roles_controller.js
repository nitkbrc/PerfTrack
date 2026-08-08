import { Controller } from "@hotwired/stimulus"

// Stages raise-on-behalf toggles on the review roles index and saves them in one bulk POST.
export default class extends Controller {
  static targets = ["form", "unsavedBar"]

  connect() {
    this._dirty = false
    this._saving = false

    this.warnBeforeUnload = (event) => {
      if (!this._dirty || this._saving) return
      event.preventDefault()
      event.returnValue = ""
    }
    window.addEventListener("beforeunload", this.warnBeforeUnload)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.warnBeforeUnload)
  }

  toggleChanged(event) {
    const checkbox = event.currentTarget
    this.syncStatusLabel(checkbox)
    this.markDirty()
  }

  syncStatusLabel(checkbox) {
    const label = checkbox.closest("label")?.querySelector("[data-raiseable-status]")
    if (!label) return

    const on = checkbox.checked
    label.textContent = on ? "On" : "Off"
    label.classList.toggle("text-slate-700", on)
    label.classList.toggle("text-slate-400", !on)
  }

  markDirty() {
    this._dirty = true
    this.unsavedBarTarget.classList.remove("hidden")
  }

  discard(event) {
    // Full reload restores server state; beforeunload would otherwise block navigation.
    this._dirty = false
  }

  save(event) {
    event.preventDefault()
    if (this._saving) return

    this._saving = true
    this._dirty = false

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
