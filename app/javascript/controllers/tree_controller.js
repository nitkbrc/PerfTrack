import { Controller } from "@hotwired/stimulus"

// Expand/collapse nested <details> nodes in a hierarchy tree.
// One toggle button: "Expand all" unless every node is open, then "Collapse all".
export default class extends Controller {
  static targets = [ "node", "toggle" ]

  connect() {
    this.boundSync = () => this.syncToggle()
    this.element.addEventListener("toggle", this.boundSync, true)
    this.syncToggle()
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.boundSync, true)
  }

  nodeTargetConnected() {
    this.syncToggle()
  }

  nodeTargetDisconnected() {
    this.syncToggle()
  }

  toggle() {
    if (this.allExpanded) {
      this.collapseAll()
    } else {
      this.expandAll()
    }
  }

  expandAll() {
    this.nodeTargets.forEach((node) => { node.open = true })
    this.syncToggle()
  }

  collapseAll() {
    this.nodeTargets.forEach((node) => { node.open = false })
    this.syncToggle()
  }

  get allExpanded() {
    return this.nodeTargets.length > 0 && this.nodeTargets.every((node) => node.open)
  }

  syncToggle() {
    if (!this.hasToggleTarget) return

    const collapsing = this.allExpanded
    this.toggleTarget.textContent = collapsing ? "Collapse all" : "Expand all"
    this.toggleTarget.setAttribute("aria-expanded", collapsing ? "true" : "false")
  }
}
