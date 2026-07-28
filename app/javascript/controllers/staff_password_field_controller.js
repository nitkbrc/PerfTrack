import { Controller } from "@hotwired/stimulus"

// Staff CSV password: green when blank (auto-generate) or length >= 6;
// red with hint when 1–5 characters. Borders are only red or green.
export default class extends Controller {
  static targets = [ "input", "hint" ]

  static okClasses = [
    "border-green-600",
    "focus:border-green-600",
    "focus:ring-green-600/40"
  ]

  static badClasses = [
    "border-red-600",
    "focus:border-red-600",
    "focus:ring-red-600/40"
  ]

  static baseBorderClasses = [
    "border-slate-300",
    "focus:border-[#000666]",
    "focus:ring-[#668efe]/40"
  ]

  connect() {
    // remembered-field may restore localStorage after this connects
    this.sync()
    requestAnimationFrame(() => this.sync())
  }

  sync() {
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value
    const ok = value.length === 0 || value.length >= 6

    this.constructor.baseBorderClasses.forEach((c) => this.inputTarget.classList.remove(c))
    this.constructor.okClasses.forEach((c) => this.inputTarget.classList.toggle(c, ok))
    this.constructor.badClasses.forEach((c) => this.inputTarget.classList.toggle(c, !ok))

    if (this.hasHintTarget) {
      this.hintTarget.hidden = ok
    }
  }
}
