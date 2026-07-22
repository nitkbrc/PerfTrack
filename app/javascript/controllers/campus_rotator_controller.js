import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]
  static values = { full: Boolean }

  connect() {
    this.index = 0
    this.show(this.index)
    if (this.imageTargets.length > 1) {
      this.timer = setInterval(() => {
        this.index = (this.index + 1) % this.imageTargets.length
        this.show(this.index)
      }, 10_000)
    }
  }

  disconnect() {
    clearInterval(this.timer)
  }

  show(index) {
    const activeOpacity = this.fullValue ? "1" : "1"
    this.imageTargets.forEach((image, imageIndex) => {
      image.style.opacity = imageIndex === index ? activeOpacity : "0"
    })
  }
}
