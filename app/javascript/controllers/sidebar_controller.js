import { Controller } from "@hotwired/stimulus"
import { restoreOptimisticNav } from "page_nav_helpers"

const OPEN_CLASS = "sidebar-open"

// Mobile off-canvas drawer: open/close via html.sidebar-open (desktop sidebar always visible).
export default class extends Controller {
  static targets = [ "toggle", "scrim", "panel" ]

  connect() {
    restoreOptimisticNav()
    this.syncUi()
    this._onKeydown = this.onKeydown.bind(this)
    this._onNavigate = () => this.setOpen(false)
    document.addEventListener("keydown", this._onKeydown)
    document.addEventListener("turbo:before-visit", this._onNavigate)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.removeEventListener("turbo:before-visit", this._onNavigate)
  }

  toggle(event) {
    event.preventDefault()
    this.setOpen(!this.isOpen())
  }

  open(event) {
    event?.preventDefault()
    this.setOpen(true)
  }

  // Used by scrim button and nav link actions. Never preventDefault — nav links must navigate,
  // and turbo:before-visit must not be cancelled.
  close() {
    this.setOpen(false)
  }

  onKeydown(event) {
    if (event.key === "Escape" && this.isOpen()) {
      this.setOpen(false)
    }
  }

  isOpen() {
    return document.documentElement.classList.contains(OPEN_CLASS)
  }

  setOpen(open) {
    document.documentElement.classList.toggle(OPEN_CLASS, open)
    document.body.classList.toggle("scats-scroll-locked", open && this.isMobile())
    this.syncUi()
  }

  isMobile() {
    return window.matchMedia("(max-width: 767px)").matches
  }

  syncUi() {
    const open = this.isOpen()
    this.toggleTargets.forEach((toggle) => {
      toggle.setAttribute("aria-expanded", String(open))
      toggle.setAttribute("aria-label", open ? "Close navigation" : "Open navigation")
    })
  }
}
