import { Controller } from "@hotwired/stimulus"

// Full-screen notifications overlay for <details>:
// portals the layer to body (escapes sidebar stacking), locks scroll,
// closes on backdrop click, Escape, or explicit close.
//
// Important: once the layer is moved under <body>, it is outside this
// controller's element, so Stimulus targets stop resolving. Keep a
// direct DOM reference for close / teardown.
export default class extends Controller {
  static targets = [ "layer" ]

  connect() {
    this.onToggle = this.onToggle.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.onLayerClick = this.onLayerClick.bind(this)
    this.layerEl = null
    this.element.addEventListener("toggle", this.onToggle)
    if (this.element.open) this.openLayer()
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.onToggle)
    this.teardownLayer()
  }

  close(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.element.removeAttribute("open")
    // toggle may not fire in all cases; always tear down the portaled layer
    this.teardownLayer()
  }

  onToggle() {
    if (this.element.open) {
      this.openLayer()
    } else {
      this.teardownLayer()
    }
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  onLayerClick(event) {
    if (event.target.closest("[data-notifications-panel-close]")) {
      this.close(event)
    }
  }

  openLayer() {
    const layer = this.hasLayerTarget ? this.layerTarget : this.layerEl
    if (!layer) return

    this.layerEl = layer

    // Layer is portaled to <body>, so keep Turbo Frame targeting explicit.
    const frame = this.element.closest("turbo-frame")
    if (frame?.id) {
      layer.querySelectorAll("form").forEach((form) => {
        form.setAttribute("data-turbo-frame", frame.id)
      })
    }

    layer.removeEventListener("click", this.onLayerClick)
    layer.addEventListener("click", this.onLayerClick)
    document.body.appendChild(layer)
    document.body.classList.add("overflow-hidden")
    document.removeEventListener("keydown", this.onKeydown)
    document.addEventListener("keydown", this.onKeydown)
  }

  teardownLayer() {
    document.removeEventListener("keydown", this.onKeydown)
    document.body.classList.remove("overflow-hidden")

    const layer = this.layerEl || (this.hasLayerTarget ? this.layerTarget : null)
    if (!layer) return

    layer.removeEventListener("click", this.onLayerClick)

    if (layer.parentElement !== this.element) {
      this.element.appendChild(layer)
    }

    this.layerEl = null
  }
}
