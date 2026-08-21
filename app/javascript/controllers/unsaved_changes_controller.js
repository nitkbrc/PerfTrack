import { Controller } from "@hotwired/stimulus"

// Tracks Save / bulk-save surfaces against an initial snapshot.
// Reports dirty/clean to the global leave-guard; only warns when state differs.
export default class extends Controller {
  static targets = ["unsavedBar"]
  static values = {
    strategy: { type: String, default: "form" }
  }

  connect() {
    this.id = `unsaved-${crypto.randomUUID()}`
    this.initialSnapshot = null
    this.currentSnapshot = null

    this.onDomChange = () => {
      if (this.strategyValue !== "form") return
      this.refreshFromForm()
    }

    this.onCustomSnapshot = (event) => {
      if (this.strategyValue !== "custom") return
      const snapshot = event.detail?.snapshot
      if (typeof snapshot !== "string") return
      this.applySnapshot(snapshot, { seedInitial: Boolean(event.detail?.seedInitial) })
    }

    this.onSubmitStart = () => {
      // Allow Turbo redirect through the leave guard without permanently
      // treating the pre-save values as the new baseline until success.
      this.publishClean()
    }

    this.onSubmitEnd = (event) => {
      if (event.detail?.success) {
        this.markClean({ acceptCurrentAsInitial: true })
        return
      }
      this.syncDirty()
    }

    this.onSaveRequest = (event) => {
      const dirtyIds = event.detail?.dirtyIds
      if (Array.isArray(dirtyIds)) {
        if (!dirtyIds.includes(this.id)) return
      } else if (!this.isDirty()) {
        return
      }

      // Always honor an explicit Save & exit request from the leave modal.
      document.dispatchEvent(new CustomEvent("leave-guard:save-started", { bubbles: true }))

      if (this.strategyValue === "form") {
        const form = this.element.matches("form") ? this.element : this.element.querySelector("form")
        if (!form) {
          document.dispatchEvent(new CustomEvent("leave-guard:save-failed", { bubbles: true }))
          return
        }
        if (typeof form.requestSubmit === "function") form.requestSubmit()
        else form.submit()
        return
      }

      this.element.dispatchEvent(new CustomEvent("unsaved-changes:save", { bubbles: true }))
    }

    this.onPing = () => {
      this.syncDirty()
    }

    this.element.addEventListener("input", this.onDomChange)
    this.element.addEventListener("change", this.onDomChange)
    this.element.addEventListener("unsaved-changes:snapshot", this.onCustomSnapshot)
    this.element.addEventListener("turbo:submit-start", this.onSubmitStart)
    this.element.addEventListener("submit", this.onSubmitStart)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
    document.addEventListener("leave-guard:save", this.onSaveRequest)
    document.addEventListener("leave-guard:ping", this.onPing)

    if (this.strategyValue === "form") {
      this.refreshFromForm({ seedInitial: true })
    } else {
      this.element.dispatchEvent(new CustomEvent("unsaved-changes:request-snapshot", { bubbles: true }))
      // If the sibling custom controller connected later, retry once.
      queueMicrotask(() => {
        if (this.initialSnapshot !== null) return
        this.element.dispatchEvent(new CustomEvent("unsaved-changes:request-snapshot", { bubbles: true }))
      })
    }
  }

  disconnect() {
    this.element.removeEventListener("input", this.onDomChange)
    this.element.removeEventListener("change", this.onDomChange)
    this.element.removeEventListener("unsaved-changes:snapshot", this.onCustomSnapshot)
    this.element.removeEventListener("turbo:submit-start", this.onSubmitStart)
    this.element.removeEventListener("submit", this.onSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    document.removeEventListener("leave-guard:save", this.onSaveRequest)
    document.removeEventListener("leave-guard:ping", this.onPing)
    this.publishClean()
  }

  isDirty() {
    return this.initialSnapshot !== null &&
      this.currentSnapshot !== null &&
      this.currentSnapshot !== this.initialSnapshot
  }

  // Used by Discard links that reload the page: clear before navigating.
  allowLeave() {
    this.markClean({ acceptCurrentAsInitial: true })
  }

  // Bar / leave-guard Save button. Form strategy submits the form; custom
  // strategy dispatches unsaved-changes:save for a sibling controller.
  save(event) {
    event?.preventDefault?.()
    this.onSaveRequest({ detail: {} })
  }

  refreshFromForm({ seedInitial = false } = {}) {
    const form = this.element.matches("form") ? this.element : this.element.querySelector("form")
    if (!form) return

    this.applySnapshot(this.serializeForm(form), { seedInitial })
  }

  applySnapshot(snapshot, { seedInitial = false } = {}) {
    this.currentSnapshot = snapshot
    if (this.initialSnapshot === null || seedInitial) {
      this.initialSnapshot = snapshot
    }
    this.syncDirty()
  }

  markClean({ acceptCurrentAsInitial = false } = {}) {
    if (acceptCurrentAsInitial) {
      this.initialSnapshot = this.currentSnapshot
    }
    this.syncDirty()
  }

  syncDirty() {
    const dirty = this.isDirty()

    if (dirty) {
      this.publishDirty()
      if (this.hasUnsavedBarTarget) this.unsavedBarTarget.classList.remove("hidden")
    } else {
      this.publishClean()
      if (this.hasUnsavedBarTarget) this.unsavedBarTarget.classList.add("hidden")
    }
  }

  publishDirty() {
    document.dispatchEvent(new CustomEvent("leave-guard:dirty", { detail: { id: this.id } }))
  }

  publishClean() {
    document.dispatchEvent(new CustomEvent("leave-guard:clean", { detail: { id: this.id } }))
  }

  serializeForm(form) {
    const entries = []
    const checkboxNames = new Set()

    form.querySelectorAll('input[type="checkbox"][name]').forEach((el) => {
      if (!el.disabled) checkboxNames.add(el.name)
    })

    form.querySelectorAll("input, select, textarea").forEach((el) => {
      if (!el.name || el.disabled) return
      if (el.name === "authenticity_token" || el.name === "payload" || el.name === "commit") return
      if (el.type === "submit" || el.type === "button" || el.type === "image" || el.type === "reset") return

      // Skip Rails' unchecked-checkbox companion hidden fields; the checkbox
      // entry below already encodes checked vs unchecked.
      if (el.type === "hidden" && checkboxNames.has(el.name)) return

      if (el.type === "file") {
        const file = el.files?.[0]
        entries.push([el.name, file ? `${file.name}:${file.size}:${file.lastModified}` : ""])
        return
      }
      if (el.type === "checkbox" || el.type === "radio") {
        if (el.checked) entries.push([el.name, el.value || "1"])
        else if (el.type === "checkbox") entries.push([el.name, "__unchecked__"])
        return
      }
      entries.push([el.name, el.value ?? ""])
    })

    entries.sort((a, b) => {
      if (a[0] === b[0]) return String(a[1]).localeCompare(String(b[1]))
      return a[0].localeCompare(b[0])
    })

    return JSON.stringify(entries)
  }
}
