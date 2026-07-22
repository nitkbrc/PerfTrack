const SIDEBAR_ACTIVE = "scats-nav-link-active"
const BOTTOM_ACTIVE = "scats-bottom-nav-link-active"
const PAGE_LOADING = "scats-page-loading"
const OPTIMISTIC_KEY = "scats-optimistic-nav"

export function setOptimisticNav(link) {
  if (!(link instanceof HTMLAnchorElement)) return

  document.querySelectorAll(".scats-nav-link, .scats-bottom-nav-link").forEach((el) => {
    el.classList.remove(SIDEBAR_ACTIVE, BOTTOM_ACTIVE)
    el.removeAttribute("aria-current")
  })

  if (link.classList.contains("scats-nav-link")) {
    link.classList.add(SIDEBAR_ACTIVE)
  }
  if (link.classList.contains("scats-bottom-nav-link")) {
    link.classList.add(BOTTOM_ACTIVE)
  }
  link.setAttribute("aria-current", "page")

  try {
    const url = new URL(link.href, window.location.href)
    sessionStorage.setItem(OPTIMISTIC_KEY, `${url.pathname}${url.search}`)
  } catch {
    // ignore
  }
}

export function restoreOptimisticNav() {
  let key = null
  try {
    key = sessionStorage.getItem(OPTIMISTIC_KEY)
  } catch {
    return
  }
  if (!key) return

  const match = Array.from(document.querySelectorAll(".scats-nav-link, .scats-bottom-nav-link")).find((el) => {
    if (!(el instanceof HTMLAnchorElement)) return false
    try {
      const url = new URL(el.href, window.location.href)
      return `${url.pathname}${url.search}` === key
    } catch {
      return false
    }
  })

  if (match) setOptimisticNav(match)
}

export function clearOptimisticNavStorage() {
  try {
    sessionStorage.removeItem(OPTIMISTIC_KEY)
  } catch {
    // ignore
  }
}

export function shouldHandlePageNav(link) {
  if (!(link instanceof HTMLAnchorElement)) return false
  if (link.dataset.turbo === "false") return false

  const frame = link.getAttribute("data-turbo-frame")
  if (frame && frame !== "_top") return false

  if (link.target === "_blank") return false
  if (link.hasAttribute("download")) return false

  const href = link.getAttribute("href")
  if (!href || href.startsWith("#") || href.toLowerCase().startsWith("javascript:")) return false

  try {
    const url = new URL(link.href, window.location.href)
    if (url.origin !== window.location.origin) return false
    if (
      url.pathname === window.location.pathname &&
      url.search === window.location.search &&
      url.hash &&
      url.hash !== window.location.hash
    ) {
      return false
    }
  } catch {
    return false
  }

  const method = (link.dataset.turboMethod || link.dataset.method || "get").toLowerCase()
  if (method !== "get") return false

  return true
}

export function beginPageNavigation(link) {
  if (!(link instanceof HTMLAnchorElement)) return false

  // Always jump the highlight immediately on the chosen nav tag.
  setOptimisticNav(link)

  if (!shouldHandlePageNav(link)) return false

  document.documentElement.classList.add(PAGE_LOADING)
  return true
}

export function endPageNavigation() {
  document.documentElement.classList.remove(PAGE_LOADING)
}

export function finishPageNavigation() {
  endPageNavigation()
  clearOptimisticNavStorage()
}
