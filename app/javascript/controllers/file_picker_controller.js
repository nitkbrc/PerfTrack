import { Controller } from "@hotwired/stimulus"

// Custom file trigger: only the button opens the picker (not the whole row).
export default class extends Controller {
  static targets = [ "input", "name" ]

  pick(event) {
    event.preventDefault()
    this.inputTarget.click()
  }

  changed() {
    if (!this.hasNameTarget) return

    const file = this.inputTarget.files?.[0]
    this.nameTarget.textContent = file ? file.name : "No file chosen"
  }
}
