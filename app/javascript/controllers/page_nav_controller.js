import { Controller } from "@hotwired/stimulus"
import {
  beginPageNavigation,
  endPageNavigation,
  finishPageNavigation,
  restoreOptimisticNav
} from "page_nav_helpers"

// Body-level: optimistic active + thin page-loading bar for sidebar / bottom-nav.
export default class extends Controller {
  connect() {
    restoreOptimisticNav()

    this._onLoad = () => finishPageNavigation()
    this._onError = () => endPageNavigation()
    this._onBeforeCache = () => endPageNavigation()

    document.addEventListener("turbo:load", this._onLoad)
    document.addEventListener("turbo:before-cache", this._onBeforeCache)
    document.addEventListener("turbo:frame-missing", this._onError)
    document.addEventListener("turbo:fetch-request-error", this._onError)
    document.addEventListener("turbo:visit", this._onVisit)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this._onLoad)
    document.removeEventListener("turbo:before-cache", this._onBeforeCache)
    document.removeEventListener("turbo:frame-missing", this._onError)
    document.removeEventListener("turbo:fetch-request-error", this._onError)
    document.removeEventListener("turbo:visit", this._onVisit)
  }

  // mousedown/click from nav links — jump selection immediately
  activate(event) {
    const link = event.currentTarget
    if (!(link instanceof HTMLAnchorElement)) return
    if (event.type === "mousedown" && event.button !== 0) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    beginPageNavigation(link)
  }

  _onVisit = (event) => {
    if (event.detail?.action === "restore") {
      endPageNavigation()
    }
  }
}
