import { Controller } from "@hotwired/stimulus"

// One-version-at-a-time carousel. Starts on the latest slide; arrows show only
// when a previous (older) or next (newer) version exists.
export default class extends Controller {
  static targets = [ "slide", "prev", "next" ]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    if (this.slideTargets.length === 0) return

    if (this.indexValue < 0 || this.indexValue >= this.slideTargets.length) {
      this.indexValue = this.slideTargets.length - 1
    }

    this.#show(this.indexValue)
  }

  prev(event) {
    event.preventDefault()
    if (this.indexValue <= 0) return
    this.#show(this.indexValue - 1)
  }

  next(event) {
    event.preventDefault()
    if (this.indexValue >= this.slideTargets.length - 1) return
    this.#show(this.indexValue + 1)
  }

  #show(index) {
    this.indexValue = index

    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("hidden", i !== index)
    })

    this.#updateArrows()
  }

  #updateArrows() {
    const atStart = this.indexValue <= 0
    const atEnd = this.indexValue >= this.slideTargets.length - 1

    if (this.hasPrevTarget) {
      this.prevTarget.hidden = atStart || this.slideTargets.length <= 1
      this.prevTarget.disabled = atStart || this.slideTargets.length <= 1
    }

    if (this.hasNextTarget) {
      this.nextTarget.hidden = atEnd || this.slideTargets.length <= 1
      this.nextTarget.disabled = atEnd || this.slideTargets.length <= 1
    }
  }
}
