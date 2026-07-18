import { Controller } from "@hotwired/stimulus"

// Copies the chosen reason template's text into the comment box. Selecting a
// template replaces the text; anything typed afterwards is left alone.
export default class extends Controller {
  static targets = ["select", "comment"]
  static values = { templates: Object }

  fill() {
    const text = this.templatesValue[this.selectTarget.value]
    if (text) this.commentTarget.value = text
  }
}
