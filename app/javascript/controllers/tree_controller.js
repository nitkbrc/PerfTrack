import { Controller } from "@hotwired/stimulus"

// Expand/collapse nested <details> nodes in a hierarchy tree.
export default class extends Controller {
  static targets = [ "node" ]

  expandAll() {
    this.nodeTargets.forEach((node) => { node.open = true })
  }

  collapseAll() {
    this.nodeTargets.forEach((node) => { node.open = false })
  }
}
