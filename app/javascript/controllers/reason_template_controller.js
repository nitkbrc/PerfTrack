import { Controller } from "@hotwired/stimulus"

// Canned reasons are read-only. Other reveals a free-text comment field.
export default class extends Controller {
  static targets = ["select", "comment", "preview", "previewText", "otherField"]
  static values = {
    templates: Object,
    other: { type: String, default: "other" }
  }

  connect() {
    this.changed()
  }

  changed() {
    const value = this.hasSelectTarget ? this.selectTarget.value : ""

    if (!value) {
      this.hidePreview()
      this.hideOther()
      return
    }

    if (value === this.otherValue) {
      this.hidePreview()
      this.showOther()
      return
    }

    const text = this.templatesValue[value]
    if (text) {
      this.showPreview(text)
      this.hideOther()
      if (this.hasCommentTarget) this.commentTarget.value = ""
    } else {
      this.hidePreview()
      this.hideOther()
    }
  }

  showPreview(text) {
    if (!this.hasPreviewTarget || !this.hasPreviewTextTarget) return
    this.previewTextTarget.textContent = text
    this.previewTarget.classList.remove("hidden")
  }

  hidePreview() {
    if (!this.hasPreviewTarget) return
    this.previewTarget.classList.add("hidden")
    if (this.hasPreviewTextTarget) this.previewTextTarget.textContent = ""
  }

  showOther() {
    if (!this.hasOtherFieldTarget) return
    this.otherFieldTarget.classList.remove("hidden")
    if (this.hasCommentTarget) {
      this.commentTarget.required = true
    }
  }

  hideOther() {
    if (!this.hasOtherFieldTarget) return
    this.otherFieldTarget.classList.add("hidden")
    if (this.hasCommentTarget) {
      this.commentTarget.required = false
      this.commentTarget.value = ""
    }
  }
}
