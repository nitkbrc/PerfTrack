import { Controller } from "@hotwired/stimulus"

const NEXT_URL_KEY = "leave-guard:next-url"

// Global leave confirm for dirty Save / bulk-save surfaces.
// Custom modal covers Turbo in-app navigation; beforeunload covers tab close.
export default class extends Controller {
  static targets = ["root", "dialog", "saveButton"]

  connect() {
    this.dirtySources = new Set()
    this.pendingUrl = null
    this.allowNextVisit = false
    this.saving = false
    this._saveStarted = false
    this._resumeTimer = null

    this.onDirty = (event) => {
      const id = event.detail?.id
      if (!id) return
      this.dirtySources.add(id)
    }

    this.onClean = (event) => {
      const id = event.detail?.id
      if (!id) return
      this.dirtySources.delete(id)
    }

    this.onBeforeVisit = (event) => {
      if (this.allowNextVisit) {
        this.allowNextVisit = false
        return
      }
      // While Save & exit is in flight, allow the save redirect through.
      if (this.saving || sessionStorage.getItem(NEXT_URL_KEY)) return
      if (this.dirtySources.size === 0) return

      event.preventDefault()
      this.pendingUrl = event.detail.url
      this.open()
    }

    this.onBeforeUnload = (event) => {
      if (this.dirtySources.size === 0 || this.saving) return
      if (sessionStorage.getItem(NEXT_URL_KEY)) return
      event.preventDefault()
      event.returnValue = ""
    }

    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.isOpen()) this.stay()
    }

    this.onSubmitEnd = (event) => {
      if (!sessionStorage.getItem(NEXT_URL_KEY)) return

      // Only abort the exit when Turbo reports an explicit failure.
      if (event.detail?.success === false) {
        sessionStorage.removeItem(NEXT_URL_KEY)
        this.saving = false
        this._saveStarted = false
        this.setSavingUi(false)
        return
      }

      // Save redirect will remount the page; resume on turbo:load / connect.
      this.saving = false
      this.dirtySources.clear()
      this.close()
    }

    this.onSaveStarted = () => {
      this._saveStarted = true
    }

    this.onSaveFailed = () => {
      if (!sessionStorage.getItem(NEXT_URL_KEY) && !this.saving) return
      sessionStorage.removeItem(NEXT_URL_KEY)
      this.saving = false
      this._saveStarted = false
      this.setSavingUi(false)
    }

    document.addEventListener("leave-guard:dirty", this.onDirty)
    document.addEventListener("leave-guard:clean", this.onClean)
    document.addEventListener("leave-guard:save-started", this.onSaveStarted)
    document.addEventListener("leave-guard:save-failed", this.onSaveFailed)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
    document.addEventListener("turbo:load", this.resumePendingNavigation)
    window.addEventListener("beforeunload", this.onBeforeUnload)
    window.addEventListener("keydown", this.onKeydown)

    this.resumePendingNavigation()
  }

  disconnect() {
    if (this._resumeTimer) {
      window.clearTimeout(this._resumeTimer)
      this._resumeTimer = null
    }
    document.removeEventListener("leave-guard:dirty", this.onDirty)
    document.removeEventListener("leave-guard:clean", this.onClean)
    document.removeEventListener("leave-guard:save-started", this.onSaveStarted)
    document.removeEventListener("leave-guard:save-failed", this.onSaveFailed)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    document.removeEventListener("turbo:load", this.resumePendingNavigation)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    window.removeEventListener("keydown", this.onKeydown)
  }

  stay() {
    this.pendingUrl = null
    this.saving = false
    this._saveStarted = false
    sessionStorage.removeItem(NEXT_URL_KEY)
    this.setSavingUi(false)
    this.close()
  }

  leave() {
    const url = this.pendingUrl
    this.pendingUrl = null
    this.saving = false
    this._saveStarted = false
    sessionStorage.removeItem(NEXT_URL_KEY)
    this.dirtySources.clear()
    this.close()
    if (!url) return

    this.navigate(url)
  }

  saveAndLeave() {
    if (this.saving) return

    const url = this.pendingUrl
    if (!url) {
      this.stay()
      return
    }

    if (this.dirtySources.size === 0) {
      this.leave()
      return
    }

    sessionStorage.setItem(NEXT_URL_KEY, url)
    this.saving = true
    this._saveStarted = false
    this.setSavingUi(true)

    document.dispatchEvent(new CustomEvent("leave-guard:save", {
      bubbles: true,
      detail: { dirtyIds: [...this.dirtySources] }
    }))

    // If nothing handled the save request, just exit.
    queueMicrotask(() => {
      if (this._saveStarted) return
      this.saving = false
      this.setSavingUi(false)
      this.leave()
    })
  }

  open() {
    this.saving = false
    this._saveStarted = false
    this.setSavingUi(false)
    this.rootTarget.classList.remove("hidden")
    this.rootTarget.classList.add("flex")
    this.rootTarget.setAttribute("aria-hidden", "false")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.rootTarget.classList.add("hidden")
    this.rootTarget.classList.remove("flex")
    this.rootTarget.setAttribute("aria-hidden", "true")
    document.body.classList.remove("overflow-hidden")
  }

  isOpen() {
    return !this.rootTarget.classList.contains("hidden")
  }

  setSavingUi(saving) {
    if (!this.hasSaveButtonTarget) return
    this.saveButtonTarget.disabled = saving
    this.saveButtonTarget.classList.toggle("opacity-60", saving)
    this.saveButtonTarget.classList.toggle("pointer-events-none", saving)
    this.saveButtonTarget.innerHTML = saving
      ? '<span class="material-symbols-outlined scats-spin text-[18px]" aria-hidden="true">progress_activity</span> Saving…'
      : '<span class="material-symbols-outlined text-[18px]" aria-hidden="true">save</span> Save & exit'
  }

  resumePendingNavigation = () => {
    const url = sessionStorage.getItem(NEXT_URL_KEY)
    if (!url) return

    // Still on the page we saved from / redirected back to — continue to the
    // destination the user originally picked. Use a hard assign so Turbo's
    // in-flight save redirect cannot cancel the exit.
    if (this.samePage(url, window.location.href)) {
      sessionStorage.removeItem(NEXT_URL_KEY)
      return
    }

    if (this._resumeTimer) window.clearTimeout(this._resumeTimer)
    this._resumeTimer = window.setTimeout(() => {
      this._resumeTimer = null
      const pending = sessionStorage.getItem(NEXT_URL_KEY)
      if (!pending) return
      if (this.samePage(pending, window.location.href)) {
        sessionStorage.removeItem(NEXT_URL_KEY)
        return
      }

      sessionStorage.removeItem(NEXT_URL_KEY)
      this.pendingUrl = null
      this.saving = true
      this.dirtySources.clear()
      this.close()
      window.location.assign(pending)
    }, 0)
  }

  navigate(url) {
    this.allowNextVisit = true
    this.dirtySources.clear()
    if (window.Turbo?.visit) {
      window.Turbo.visit(url)
    } else {
      window.location.href = url
    }
  }

  samePage(a, b) {
    try {
      const left = new URL(a, window.location.origin)
      const right = new URL(b, window.location.origin)
      return left.pathname + left.search === right.pathname + right.search
    } catch {
      return a === b
    }
  }
}
