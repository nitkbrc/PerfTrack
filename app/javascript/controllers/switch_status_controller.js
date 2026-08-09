import { Controller } from "@hotwired/stimulus"

// Keeps a status label in sync with a checkbox switch.
export default class extends Controller {
  static targets = ["input", "status"]
  static values = {
    on: { type: String, default: "Allowed" },
    off: { type: String, default: "Blocked" }
  }

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasInputTarget || !this.hasStatusTarget) return

    const on = this.inputTarget.checked
    this.statusTarget.textContent = on ? this.onValue : this.offValue
    this.statusTarget.classList.toggle("text-slate-700", on && this.onValue === "Allowed")
    this.statusTarget.classList.toggle("text-emerald-700", on)
    this.statusTarget.classList.toggle("text-slate-400", !on)

    if (this.onValue === "Editable") {
      this.statusTarget.innerHTML = on
        ? '<span class="h-1.5 w-1.5 rounded-full bg-emerald-500" aria-hidden="true"></span> Editable'
        : "Locked"
    }
  }
}
