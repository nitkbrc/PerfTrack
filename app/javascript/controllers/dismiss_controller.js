import { Controller } from "@hotwired/stimulus"

// Closes dismissable UI: flash messages (remove) and <details> dropdowns (close).
export default class extends Controller {
  remove() {
    this.element.remove()
  }

  close() {
    this.element.removeAttribute("open")
  }
}
