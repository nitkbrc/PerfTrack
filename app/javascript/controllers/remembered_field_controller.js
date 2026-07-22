import { Controller } from "@hotwired/stimulus"

// Prefills an input from localStorage (or a default), and remembers edits
// so the value stays until the user changes it again.
export default class extends Controller {
  static values = {
    key: String,
    default: String
  }

  connect() {
    const stored = localStorage.getItem(this.storageKey)
    if (stored !== null) {
      this.element.value = stored
    } else if (!this.element.value) {
      this.element.value = this.defaultValue
    }
  }

  persist() {
    localStorage.setItem(this.storageKey, this.element.value)
  }

  get storageKey() {
    return this.keyValue || `scats:remembered:${this.element.name || this.element.id}`
  }
}
