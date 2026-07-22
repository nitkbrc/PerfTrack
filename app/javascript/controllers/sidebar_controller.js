import { Controller } from "@hotwired/stimulus"
import { beginPageNavigation, restoreOptimisticNav } from "page_nav_helpers"

const STORAGE_KEY = "scats-sidebar-expanded"
// Let width/label transitions play before Turbo replaces the sidebar DOM.
const EXPAND_BEFORE_VISIT_MS = 220

// Collapsed-by-default desktop sidebar: expand via toggle, nav click, or focus.
export default class extends Controller {
  static targets = [ "toggle" ]

  connect() {
    this.setExpanded(sessionStorage.getItem(STORAGE_KEY) === "true")
    restoreOptimisticNav()
  }

  disconnect() {
    this.clearScheduledVisit()
  }

  toggle(event) {
    event.preventDefault()
    this.clearScheduledVisit()
    this.setExpanded(!this.isExpanded())
  }

  // mousedown runs before focus. When collapsed, expand + navigate here so the
  // focus handler cannot expand first (making click think we were already open)
  // and so the width transition cannot cancel the browser's default click nav.
  prepareVisit(event) {
    if (event.button !== 0) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    const link = event.currentTarget
    if (!(link instanceof HTMLAnchorElement)) return

    const href = link.getAttribute("href")
    if (!href || href.startsWith("#")) return

    // Jump active highlight + thin loader immediately (before expand delay).
    beginPageNavigation(link)

    if (this.isExpanded()) return

    this.setExpanded(true)
    event.preventDefault()
    this._navigatedFromCollapsed = true
    this.scheduleVisit(link.href)
  }

  // focus: expand for keyboard users.
  // click: keep expanded; if prepareVisit already navigated, swallow the click.
  expand(event) {
    this.setExpanded(true)

    if (event.type === "focus") return

    if (this._navigatedFromCollapsed) {
      event.preventDefault()
      this._navigatedFromCollapsed = false
    }
  }

  scheduleVisit(url) {
    this.clearScheduledVisit()

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.visit(url)
      return
    }

    // Double rAF ensures the expanded class is painted so width transition starts
    // before we navigate (Turbo Drive replaces the sidebar and would kill it).
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this._visitTimer = window.setTimeout(() => {
          this._visitTimer = null
          this.visit(url)
        }, EXPAND_BEFORE_VISIT_MS)
      })
    })
  }

  clearScheduledVisit() {
    if (this._visitTimer != null) {
      window.clearTimeout(this._visitTimer)
      this._visitTimer = null
    }
  }

  visit(url) {
    if (typeof Turbo !== "undefined" && Turbo.visit) {
      Turbo.visit(url)
    } else {
      window.location.assign(url)
    }
  }

  isExpanded() {
    return document.documentElement.classList.contains("sidebar-expanded")
  }

  setExpanded(expanded) {
    document.documentElement.classList.toggle("sidebar-expanded", expanded)
    this.element.classList.toggle("scats-sidebar--expanded", expanded)
    sessionStorage.setItem(STORAGE_KEY, String(expanded))

    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", String(expanded))
      this.toggleTarget.setAttribute(
        "aria-label",
        expanded ? "Collapse sidebar" : "Expand sidebar"
      )
    }
  }
}
