import { Controller } from "@hotwired/stimulus"

// Sliding segmented control (iOS-style pill). Syncs an optional hidden
// <select>/<input> and dispatches segmented-switch:change with { value }.
export default class extends Controller {
  static targets = [ "option", "pill", "input", "track" ]
  static values = { selected: String }

  connect() {
    this.apply({ animate: false })
  }

  select(event) {
    this.#choose(event.currentTarget.dataset.value, { focus: false })
  }

  keydown(event) {
    const keys = [ "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End" ]
    if (!keys.includes(event.key)) return

    event.preventDefault()
    const options = this.optionTargets
    if (options.length === 0) return

    const current = options.findIndex((o) => o.dataset.value === this.selectedValue)
    let next = Math.max(current, 0)

    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      next = (current + 1) % options.length
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      next = (current - 1 + options.length) % options.length
    } else if (event.key === "Home") {
      next = 0
    } else if (event.key === "End") {
      next = options.length - 1
    }

    this.#choose(options[next].dataset.value, { focus: true })
  }

  apply({ animate = true } = {}) {
    const track = this.hasTrackTarget ? this.trackTarget : this.element
    const index = this.optionTargets.findIndex((o) => o.dataset.value === this.selectedValue)
    const safeIndex = index < 0 ? 0 : index

    track.style.setProperty("--scats-switch-count", String(this.optionTargets.length || 1))
    track.style.setProperty("--scats-switch-index", String(safeIndex))

    if (this.hasPillTarget) {
      this.pillTarget.style.transition = animate ? null : "none"
    }

    this.optionTargets.forEach((option, i) => {
      const active = i === safeIndex
      const isRadio = option.getAttribute("role") === "radio"

      option.setAttribute("aria-selected", active ? "true" : "false")
      if (isRadio) option.setAttribute("aria-checked", active ? "true" : "false")
      option.tabIndex = active ? 0 : -1
      option.classList.toggle("scats-switch__option--active", active)
    })

    if (this.hasPillTarget && !animate) {
      // Re-enable transition after the initial paint without a slide-from-zero flash.
      requestAnimationFrame(() => {
        this.pillTarget.style.transition = null
      })
    }
  }

  syncInput() {
    if (!this.hasInputTarget) return
    if (this.inputTarget.value === this.selectedValue) return

    this.inputTarget.value = this.selectedValue
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #choose(value, { focus }) {
    if (!value || value === this.selectedValue) {
      if (focus) {
        this.optionTargets.find((o) => o.dataset.value === this.selectedValue)?.focus()
      }
      return
    }

    this.selectedValue = value
    this.apply({ animate: true })
    this.syncInput()
    if (focus) {
      this.optionTargets.find((o) => o.dataset.value === value)?.focus()
    }
    this.dispatch("change", { detail: { value } })
  }
}
