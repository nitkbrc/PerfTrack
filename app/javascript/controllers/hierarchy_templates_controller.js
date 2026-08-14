import { Controller } from "@hotwired/stimulus"

const ROLE_BADGE_PALETTE = [
  "bg-slate-800 text-white",
  "bg-blue-600 text-white",
  "bg-teal-700 text-white",
  "bg-indigo-600 text-white",
  "bg-cyan-700 text-white",
  "bg-violet-600 text-white"
]

const ROLE_BADGE_KNOWN = {
  Dean: "bg-blue-600 text-white",
  Supervisor: "bg-teal-700 text-white",
  "Associate Dean": "bg-indigo-600 text-white"
}

// Stages hierarchy template edits client-side and posts one bulk Save payload.
export default class extends Controller {
  static targets = ["form", "payload"]
  static values = { saveUrl: String }

  connect() {
    this._saving = false

    this.closeMenusOnOutsideClick = (event) => {
      this.element.querySelectorAll("details[data-card-menu][open], details[data-owner-menu][open]").forEach((menu) => {
        if (!menu.contains(event.target)) menu.open = false
      })
    }
    document.addEventListener("click", this.closeMenusOnOutsideClick)

    this.onSnapshotRequest = () => this.publishSnapshot({ seedInitial: true })
    this.onSaveRequest = () => {
      this._saving = false
      this.setSavingUi(false)
      this.save(new Event("submit"))
    }
    this.onSubmitEnd = () => {
      this._saving = false
      this.setSavingUi(false)
    }
    this.element.addEventListener("unsaved-changes:request-snapshot", this.onSnapshotRequest)
    this.element.addEventListener("unsaved-changes:save", this.onSaveRequest)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
    queueMicrotask(() => {
      this.publishSnapshot({ seedInitial: true })
      this.refreshAllMoveControls()
    })
  }

  disconnect() {
    document.removeEventListener("click", this.closeMenusOnOutsideClick)
    this.element.removeEventListener("unsaved-changes:request-snapshot", this.onSnapshotRequest)
    this.element.removeEventListener("unsaved-changes:save", this.onSaveRequest)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  publishSnapshot({ seedInitial = false } = {}) {
    const snapshot = JSON.stringify(this.buildState())
    this.element.dispatchEvent(new CustomEvent("unsaved-changes:snapshot", {
      bubbles: true,
      detail: { snapshot, seedInitial }
    }))
  }

  markDirty() {
    this.publishSnapshot()
  }

  buildState() {
    const hierarchies = []
    this.element.querySelectorAll("[data-hierarchy-card]").forEach((card) => {
      const displayRoles = [...card.querySelectorAll("[data-role-list] [data-role-id]")]
      const reviewRoles = [...displayRoles].reverse()
      hierarchies.push({
        id: Number(card.dataset.hierarchyId),
        name: card.dataset.hierarchyName,
        scope: card.dataset.hierarchyScope,
        roles: reviewRoles.map((el, index) => ({
          review_role_id: Number(el.dataset.roleId),
          can_raise_on_behalf: el.dataset.canRaise === "true",
          position: index + 1
        }))
      })
    })

    const reattachments = []
    this.element.querySelectorAll("[data-owner-list]").forEach((list) => {
      const hierarchyId = Number(list.dataset.hierarchyId)
      if (!hierarchyId) return
      const card = list.closest("[data-hierarchy-card]")
      const expectedType = card?.dataset.hierarchyScope === "division" ? "Division" : "SubDivision"
      list.querySelectorAll("[data-owner-id]").forEach((owner) => {
        const ownerId = Number(owner.dataset.ownerId)
        if (!ownerId || !owner.dataset.ownerType) return
        if (owner.dataset.ownerType !== expectedType) return
        reattachments.push({
          owner_type: owner.dataset.ownerType,
          owner_id: ownerId,
          hierarchy_id: hierarchyId
        })
      })
    })

    return { hierarchies, reattachments }
  }

  startRenameFromMenu(event) {
    const card = event.currentTarget.closest("[data-hierarchy-card]")
    event.currentTarget.closest("details[data-card-menu]")?.removeAttribute("open")
    this.beginRename(card)
  }

  startRename(event) {
    this.beginRename(event.currentTarget.closest("[data-hierarchy-card]"))
  }

  beginRename(card) {
    if (!card) return
    const title = card.querySelector("[data-hierarchy-title]")
    const input = card.querySelector("[data-hierarchy-name-input]")
    if (!title || !input) return

    input.value = card.dataset.hierarchyName || title.textContent.trim()
    title.classList.add("hidden")
    input.classList.remove("hidden")
    input.focus()
    input.select()
  }

  renameKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      event.currentTarget.blur()
    } else if (event.key === "Escape") {
      event.preventDefault()
      const card = event.currentTarget.closest("[data-hierarchy-card]")
      const input = event.currentTarget
      input.value = card?.dataset.hierarchyName || ""
      input.blur()
    }
  }

  commitRename(event) {
    const input = event.currentTarget
    const card = input.closest("[data-hierarchy-card]")
    const title = card?.querySelector("[data-hierarchy-title]")
    if (!card || !title) return

    const previous = (card.dataset.hierarchyName || "").trim()
    const next = input.value.trim()
    const resolved = next.length > 0 ? next : (previous.length > 0 ? previous : "Untitled hierarchy")

    card.dataset.hierarchyName = resolved
    title.textContent = resolved
    input.value = resolved
    input.classList.add("hidden")
    title.classList.remove("hidden")

    if (resolved !== previous) {
      this.refreshAllMoveControls()
      this.markDirty()
    }
  }

  scrollPrev(event) {
    this.scrollRail(event.currentTarget, -1)
  }

  scrollNext(event) {
    this.scrollRail(event.currentTarget, 1)
  }

  scrollRail(button, direction) {
    const rail = button.closest("[data-scope-section]")?.querySelector("[data-card-rail]")
    if (!rail) return
    const card = rail.querySelector("[data-hierarchy-card]")
    const step = card ? card.offsetWidth + 24 : rail.clientWidth * 0.8
    rail.scrollBy({ left: direction * step, behavior: "smooth" })
  }

  roleName(el) {
    return el?.dataset.roleName || el?.querySelector("[data-role-label]")?.textContent?.trim() || ""
  }

  roleInitials(name) {
    const parts = String(name || "").trim().split(/\s+/).filter(Boolean)
    if (parts.length === 0) return "?"
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
    return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase()
  }

  roleBadgeClasses(name) {
    if (ROLE_BADGE_KNOWN[name]) return ROLE_BADGE_KNOWN[name]
    let sum = 0
    for (const ch of String(name || "")) sum += ch.charCodeAt(0)
    return ROLE_BADGE_PALETTE[sum % ROLE_BADGE_PALETTE.length]
  }

  moveRoleUp(event) {
    this.moveListItem(event.currentTarget.closest("[data-role-id]"), -1)
  }

  moveRoleDown(event) {
    this.moveListItem(event.currentTarget.closest("[data-role-id]"), 1)
  }

  moveListItem(item, direction) {
    if (!item) return
    const sibling = direction < 0 ? item.previousElementSibling : item.nextElementSibling
    if (!sibling || !sibling.hasAttribute("data-role-id")) return

    if (direction < 0) item.parentElement.insertBefore(item, sibling)
    else item.parentElement.insertBefore(sibling, item)

    const card = item.closest("[data-hierarchy-card]")
    this.refreshRoleMeta(card)
    this.refreshMoveButtons(item.parentElement)
    this.markDirty()
  }

  openOwnerMenu(event) {
    const menu = event.currentTarget
    if (!(menu instanceof HTMLDetailsElement) || !menu.open) return
    const owner = menu.closest("[data-owner-id]")
    if (owner) this.refreshOwnerMoveMenu(owner)
  }

  moveOwnerTo(event) {
    event.preventDefault()
    const button = event.currentTarget
    const destination = button.dataset.destination
    if (!destination) return

    const owner = button.closest("[data-owner-id]")
    const section = owner?.closest("[data-scope-section]")
    button.closest("details[data-owner-menu]")?.removeAttribute("open")
    if (!owner || !section) return

    const sourceList = owner.closest("[data-owner-list]")
    let targetList = null

    if (destination === "tray") {
      targetList = section.querySelector("[data-owner-list][data-owner-tray]")
      if (!targetList) {
        alert("There is no unassigned tray in this section. Leave the unit on a template, or create one.")
        return
      }
    } else {
      const card = section.querySelector(`[data-hierarchy-card][data-hierarchy-id="${destination}"]`)
      targetList = card?.querySelector("[data-owner-list]")
      const expectedType = card?.dataset.hierarchyScope === "division" ? "Division" : "SubDivision"
      if (!targetList || owner.dataset.ownerType !== expectedType) {
        alert("That destination is not available for this unit.")
        return
      }
    }

    if (!targetList || targetList.contains(owner)) return

    this.clearListPlaceholders(targetList)
    targetList.appendChild(owner)
    this.styleOwnerForList(owner, targetList)
    this.ensureEmptyOwnersPlaceholder(sourceList)
    this.ensureEmptyTrayPlaceholder(sourceList)
    this.refreshOwnerCount(sourceList?.closest("[data-hierarchy-card]"))
    this.refreshOwnerCount(targetList.closest("[data-hierarchy-card]"))
    this.refreshMoveButtons(sourceList)
    this.refreshMoveButtons(targetList)
    this.markDirty()
  }

  removeRole(event) {
    const item = event.currentTarget.closest("[data-role-id]")
    const card = item.closest("[data-hierarchy-card]")
    const list = card.querySelector("[data-role-list]")
    if (list.querySelectorAll("[data-role-id]").length <= 1) {
      alert("Each hierarchy needs at least one role.")
      return
    }

    this.restoreRoleOption(card, {
      id: item.dataset.roleId,
      name: this.roleName(item),
      raiseable: item.dataset.canRaise === "true"
    })
    item.remove()
    this.refreshRoleMeta(card)
    this.refreshMoveButtons(list)
    this.markDirty()
  }

  toggleAddRole(event) {
    const panel = event.currentTarget.closest("[data-add-role-panel]")
    const form = panel?.querySelector("[data-add-role-form]")
    if (!form) return
    form.classList.toggle("hidden")
  }

  ownerLabel(el) {
    return el?.querySelector("[data-owner-label]")?.textContent?.replace(/\s+/g, " ").trim() || "Unnamed"
  }

  toggleAssignOwner(event) {
    const panel = event.currentTarget.closest("[data-assign-owner-panel]")
    const form = panel?.querySelector("[data-assign-owner-form]")
    const select = form?.querySelector("[data-assign-owner-select]")
    if (!form || !select) return

    const willOpen = form.classList.contains("hidden")
    form.classList.toggle("hidden")
    if (!willOpen) return

    const card = event.currentTarget.closest("[data-hierarchy-card]")
    const section = card?.closest("[data-scope-section]")
    const ownList = card?.querySelector("[data-owner-list]")
    const noun = card?.dataset.hierarchyScope === "division" ? "division" : "sub-division"

    const candidates = [...(section?.querySelectorAll("[data-owner-list] [data-owner-id]") || [])]
      .filter((owner) => !ownList?.contains(owner))
      .sort((a, b) => this.ownerLabel(a).localeCompare(this.ownerLabel(b)))

    select.innerHTML = `<option value="">Choose a ${noun}…</option>`
    candidates.forEach((owner) => {
      const option = document.createElement("option")
      option.value = `${owner.dataset.ownerType}:${owner.dataset.ownerId}`
      option.textContent = this.ownerLabel(owner)
      select.appendChild(option)
    })

    if (candidates.length === 0) {
      const option = document.createElement("option")
      option.value = ""
      option.disabled = true
      option.textContent = `Every ${noun} is already on this template`
      select.appendChild(option)
    }
    select.value = ""
  }

  assignOwner(event) {
    const select = event.currentTarget
    if (!select.value) return

    const card = select.closest("[data-hierarchy-card]")
    const section = card?.closest("[data-scope-section]")
    const list = card?.querySelector("[data-owner-list]")
    const [ownerType, ownerId] = select.value.split(":")
    const owner = section?.querySelector(
      `[data-owner-list] [data-owner-id="${ownerId}"][data-owner-type="${ownerType}"]`
    )
    if (!owner || !list) {
      select.value = ""
      return
    }

    const sourceList = owner.closest("[data-owner-list]")
    this.clearListPlaceholders(list)
    list.appendChild(owner)
    this.styleOwnerForList(owner, list)

    this.ensureEmptyOwnersPlaceholder(sourceList)
    this.ensureEmptyTrayPlaceholder(sourceList)
    this.refreshOwnerCount(sourceList?.closest("[data-hierarchy-card]"))
    this.refreshOwnerCount(card)
    this.refreshMoveButtons(sourceList)
    this.refreshMoveButtons(list)

    select.value = ""
    card?.querySelector("[data-assign-owner-form]")?.classList.add("hidden")
    this.markDirty()
  }

  ownerMoveMenuHtml(name) {
    return `
      <details class="relative shrink-0" data-owner-menu data-action="toggle->hierarchy-templates#openOwnerMenu">
        <summary class="flex h-8 w-8 cursor-pointer list-none items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-700 [&::-webkit-details-marker]:hidden"
                 aria-label="Actions for ${this.escapeHtml(name)}">
          <span class="material-symbols-outlined text-xl" aria-hidden="true">more_vert</span>
        </summary>
        <div class="absolute right-0 z-30 mt-1.5 w-56 overflow-hidden rounded-xl border border-slate-200 bg-white py-1.5 shadow-xl"
             data-owner-move-menu>
          <p class="px-4 pb-1 pt-1.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-400">Move to</p>
          <div data-owner-move-destinations>
            <p class="px-4 py-2 text-xs text-slate-400">No other destinations</p>
          </div>
        </div>
      </details>
    `
  }

  styleOwnerForList(owner, list) {
    const unstaffed = Boolean(owner.querySelector("[data-owner-unstaffed-icon]"))
    const onTray = list.hasAttribute("data-owner-tray")
    const labelHtml = owner.querySelector("[data-owner-label]")?.innerHTML
      || this.escapeHtml(this.ownerLabel(owner))
    const name = this.ownerLabel(owner)

    if (onTray) {
      owner.className = "flex max-w-full items-center gap-1 rounded-xl border border-amber-200 bg-white py-1.5 pl-3 pr-1 text-sm font-medium text-slate-700 shadow-sm"
      owner.innerHTML = `
        <span class="min-w-0 flex-1 truncate" data-owner-label>${labelHtml}</span>
        ${this.ownerMoveMenuHtml(name)}
      `
    } else {
      owner.className = `flex items-center gap-2 rounded-xl border px-2.5 py-2 text-sm transition sm:gap-3 sm:px-3 sm:py-2.5 ${
        unstaffed
          ? "border-red-200 bg-red-50/50 text-red-700"
          : "border-slate-200 bg-white text-slate-800 hover:border-slate-300"
      }`
      owner.innerHTML = `
        <span class="min-w-0 flex-1 truncate font-medium" data-owner-label>${labelHtml}</span>
        ${unstaffed
          ? '<span class="material-symbols-outlined shrink-0 text-lg text-red-500" data-owner-unstaffed-icon aria-hidden="true" title="Roles still need people">warning</span>'
          : ""}
        ${this.ownerMoveMenuHtml(name)}
      `
    }

    this.refreshOwnerMoveMenu(owner)
  }

  restoreRoleOption(card, { id, name, raiseable }) {
    if (!id || !name) return
    const panel = card.querySelector("[data-add-role-form]") || card
    let select = panel.querySelector("[data-add-role-select]")
    const note = panel.querySelector("[data-no-roles]")

    if (!select) {
      if (note) note.remove()
      select = document.createElement("select")
      select.className = "mt-0 block h-10 w-full rounded-md border border-border-subtle bg-surface-white px-3 py-2 text-sm text-text-main shadow-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-secondary-container/40"
      select.dataset.addRoleSelect = ""
      select.dataset.action = "change->hierarchy-templates#addRole"
      select.innerHTML = `<option value="">Choose a role…</option>`

      const createDetails = panel.querySelector("details")
      if (createDetails) panel.insertBefore(select, createDetails)
      else panel.prepend(select)
    }

    if ([...select.options].some((o) => o.value === String(id))) return

    const option = document.createElement("option")
    option.value = id
    option.dataset.name = name
    option.dataset.raiseable = raiseable ? "true" : "false"
    option.textContent = name
    select.appendChild(option)

    const form = card.querySelector("[data-add-role-form]")
    form?.classList.remove("hidden")
  }

  reorderControlsHtml({ upAction, downAction, label }) {
    return `
      <div class="flex shrink-0 flex-col gap-0.5" data-reorder-controls>
        <button type="button"
                class="inline-flex h-7 w-7 cursor-pointer items-center justify-center rounded-md text-slate-400 transition hover:bg-slate-100 hover:text-slate-700 disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent disabled:hover:text-slate-400"
                data-action="${upAction}"
                data-move-up
                aria-label="Move ${this.escapeHtml(label)} up">
          <span class="material-symbols-outlined text-[18px]" aria-hidden="true">keyboard_arrow_up</span>
        </button>
        <button type="button"
                class="inline-flex h-7 w-7 cursor-pointer items-center justify-center rounded-md text-slate-400 transition hover:bg-slate-100 hover:text-slate-700 disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent disabled:hover:text-slate-400"
                data-action="${downAction}"
                data-move-down
                aria-label="Move ${this.escapeHtml(label)} down">
          <span class="material-symbols-outlined text-[18px]" aria-hidden="true">keyboard_arrow_down</span>
        </button>
      </div>
    `
  }

  buildRoleItem({ id, name, canRaise }) {
    const li = document.createElement("li")
    li.className = "group relative pb-3"
    li.dataset.roleId = id
    li.dataset.roleName = name
    li.dataset.canRaise = canRaise ? "true" : "false"
    li.innerHTML = `
      <span class="pointer-events-none absolute bottom-0 left-[3.25rem] top-[3.25rem] w-px bg-slate-300 sm:left-[3.5rem]" data-role-connector aria-hidden="true"></span>
      <div class="relative flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-2.5 py-2 transition group-hover:border-slate-300 group-hover:shadow-sm sm:gap-3 sm:px-3 sm:py-2.5">
        ${this.reorderControlsHtml({
          upAction: "hierarchy-templates#moveRoleUp",
          downAction: "hierarchy-templates#moveRoleDown",
          label: name
        })}
        <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-[11px] font-bold tracking-wide ${this.roleBadgeClasses(name)}" data-role-badge>
          ${this.escapeHtml(this.roleInitials(name))}
        </span>
        <p class="min-w-0 flex-1 truncate text-sm font-medium text-slate-800" data-role-label>${this.escapeHtml(name)}</p>
        <button type="button"
                class="cursor-pointer rounded-md p-1 text-slate-300 opacity-0 transition hover:bg-red-50 hover:text-red-600 focus:opacity-100 group-hover:opacity-100"
                data-action="hierarchy-templates#removeRole"
                aria-label="Remove ${this.escapeHtml(name)}">
          <span class="material-symbols-outlined text-lg" aria-hidden="true">close</span>
        </button>
      </div>
    `
    return li
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
  }

  addRole(event) {
    const select = event.currentTarget
    const option = select.selectedOptions[0]
    if (!option?.value) return

    const card = select.closest("[data-hierarchy-card]")
    const list = card.querySelector("[data-role-list]")
    const existingIds = [...list.querySelectorAll("[data-role-id]")].map((el) => el.dataset.roleId)
    if (existingIds.includes(option.value)) {
      select.value = ""
      return
    }

    const li = this.buildRoleItem({
      id: option.value,
      name: option.dataset.name,
      canRaise: option.dataset.raiseable === "true"
    })

    list.appendChild(li)

    option.remove()
    select.value = ""
    if (![...select.options].some((o) => o.value)) {
      const form = select.closest("[data-add-role-form]")
      select.remove()
      if (form && !form.querySelector("[data-no-roles]")) {
        const note = document.createElement("p")
        note.className = "text-xs leading-relaxed text-slate-400"
        note.dataset.noRoles = "true"
        note.textContent = "All roles for this scope are already in this template."
        const details = form.querySelector("details")
        if (details) form.insertBefore(note, details)
        else form.prepend(note)
      }
    }
    this.refreshRoleMeta(card)
    this.refreshMoveButtons(list)
    this.markDirty()
  }

  clearListPlaceholders(list) {
    if (!list) return
    list.querySelectorAll("[data-empty-owners], [data-empty-tray]").forEach((el) => el.remove())
  }

  ensureEmptyOwnersPlaceholder(list) {
    if (!list) return
    if (list.hasAttribute("data-owner-tray")) return
    if (list.querySelector("[data-owner-id]")) return
    if (list.querySelector("[data-empty-owners]")) return

    const card = list.closest("[data-hierarchy-card]")
    const noun = card?.dataset.hierarchyScope === "division" ? "division" : "sub-division"
    const li = document.createElement("li")
    li.className = "rounded-xl border border-dashed border-slate-200 px-4 py-6 text-center text-xs leading-relaxed text-slate-400"
    li.dataset.emptyOwners = "true"
    li.textContent = `Nothing attached yet. Use Assign below to add a ${noun}.`
    list.appendChild(li)
  }

  ensureEmptyTrayPlaceholder(list) {
    if (!list?.hasAttribute("data-owner-tray")) return
    if (list.querySelector("[data-owner-id]")) return
    if (list.querySelector("[data-empty-tray]")) return

    const section = list.closest("[data-scope-section]")
    const noun = section?.dataset.hierarchyScope === "division" ? "division" : "sub-division"
    const li = document.createElement("li")
    li.className = "rounded-lg border border-dashed border-amber-200/80 px-3 py-2 text-xs text-amber-800/60"
    li.dataset.emptyTray = "true"
    li.textContent = `All ${noun}s are on a template.`
    list.appendChild(li)
  }

  refreshOwnerCount(card) {
    if (!card) return
    const owners = [...card.querySelectorAll("[data-owner-list] [data-owner-id]")]
    const count = owners.length
    const unstaffed = owners.filter((owner) => owner.classList.contains("border-red-200")).length

    const badge = card.querySelector("[data-owner-count]")
    if (badge) badge.textContent = String(count)

    const unstaffedBadge = card.querySelector("[data-owner-unstaffed]")
    const unstaffedCount = card.querySelector("[data-owner-unstaffed-count]")
    if (unstaffedCount) unstaffedCount.textContent = String(unstaffed)
    if (unstaffedBadge) {
      unstaffedBadge.classList.toggle("hidden", unstaffed === 0)
      unstaffedBadge.classList.toggle("inline-flex", unstaffed > 0)
    }
  }

  refreshRoleMeta(card) {
    if (!card) return
    const listItems = [...card.querySelectorAll("[data-role-list] [data-role-id]")]
    listItems.forEach((item, index) => {
      const last = index === listItems.length - 1
      item.classList.toggle("pb-3", !last)
      let connector = item.querySelector("[data-role-connector]")
      if (last) {
        connector?.remove()
      } else if (!connector) {
        connector = document.createElement("span")
        connector.className = "pointer-events-none absolute bottom-0 left-[3.25rem] top-[3.25rem] w-px bg-slate-300 sm:left-[3.5rem]"
        connector.dataset.roleConnector = ""
        connector.setAttribute("aria-hidden", "true")
        item.prepend(connector)
      }
    })
    this.refreshMoveButtons(card.querySelector("[data-role-list]"))
  }

  refreshMoveButtons(list) {
    if (!list) return
    const items = [...list.querySelectorAll(":scope > [data-role-id]")]
    items.forEach((item, index) => {
      const up = item.querySelector("[data-move-up]")
      const down = item.querySelector("[data-move-down]")
      if (up) up.disabled = index === 0
      if (down) down.disabled = index === items.length - 1
    })
  }

  refreshOwnerMoveMenu(owner) {
    const destinations = owner.querySelector("[data-owner-move-destinations]")
    if (!destinations) return

    const section = owner.closest("[data-scope-section]")
    const currentList = owner.closest("[data-owner-list]")
    const currentId = currentList?.hasAttribute("data-owner-tray")
      ? "tray"
      : currentList?.dataset.hierarchyId

    const items = []
    section?.querySelectorAll("[data-hierarchy-card]").forEach((card) => {
      const id = card.dataset.hierarchyId
      if (!id || id === currentId) return
      const name = card.dataset.hierarchyName || "Template"
      items.push(`
        <button type="button"
                class="flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-slate-700 transition hover:bg-slate-50"
                data-action="hierarchy-templates#moveOwnerTo"
                data-destination="${this.escapeHtml(id)}">
          <span class="material-symbols-outlined text-lg text-slate-400" aria-hidden="true">account_tree</span>
          <span class="min-w-0 truncate">${this.escapeHtml(name)}</span>
        </button>
      `)
    })

    if (currentId !== "tray") {
      items.push(`
        <button type="button"
                class="flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-slate-700 transition hover:bg-slate-50"
                data-action="hierarchy-templates#moveOwnerTo"
                data-destination="tray">
          <span class="material-symbols-outlined text-lg text-amber-500" aria-hidden="true">inventory_2</span>
          <span class="min-w-0 truncate">Not on a template</span>
        </button>
      `)
    }

    destinations.innerHTML = items.length > 0
      ? items.join("")
      : '<p class="px-4 py-2 text-xs leading-relaxed text-slate-400">No other destinations</p>'
  }

  refreshAllMoveControls() {
    this.element.querySelectorAll("[data-role-list], [data-owner-list]").forEach((list) => {
      this.refreshMoveButtons(list)
    })
    this.element.querySelectorAll("[data-owner-id]").forEach((owner) => {
      this.refreshOwnerMoveMenu(owner)
    })
  }

  setSavingUi(saving) {
    this.element.querySelectorAll('[data-action="hierarchy-templates#save"]').forEach((btn) => {
      btn.disabled = saving
      btn.classList.toggle("opacity-60", saving)
      btn.classList.toggle("pointer-events-none", saving)
    })
  }

  save(event) {
    event.preventDefault()
    if (this._saving) return
    this._saving = true
    this.setSavingUi(true)

    const fail = (message) => {
      if (message) alert(message)
      this._saving = false
      this.setSavingUi(false)
      document.dispatchEvent(new CustomEvent("leave-guard:save-failed", { bubbles: true }))
    }

    try {
      const cards = [...this.element.querySelectorAll("[data-hierarchy-card]")]
      if (cards.length === 0) {
        fail("No hierarchy templates to save.")
        return
      }

      const hierarchies = []
      for (const card of cards) {
        const displayRoles = [...card.querySelectorAll("[data-role-list] [data-role-id]")]
        if (displayRoles.length === 0) {
          fail(`"${card.dataset.hierarchyName}" needs at least one role.`)
          return
        }

        const roleIds = displayRoles.map((el) => Number(el.dataset.roleId)).filter((id) => id > 0)
        if (roleIds.length !== displayRoles.length || new Set(roleIds).size !== roleIds.length) {
          fail(`"${card.dataset.hierarchyName}" has invalid or duplicate roles. Refresh and try again.`)
          return
        }

        const reviewRoles = [...displayRoles].reverse()
        hierarchies.push({
          id: Number(card.dataset.hierarchyId),
          name: card.dataset.hierarchyName,
          scope: card.dataset.hierarchyScope,
          roles: reviewRoles.map((el, index) => ({
            review_role_id: Number(el.dataset.roleId),
            can_raise_on_behalf: el.dataset.canRaise === "true",
            position: index + 1
          }))
        })
      }

      const reattachments = []
      this.element.querySelectorAll("[data-owner-list]").forEach((list) => {
        const hierarchyId = Number(list.dataset.hierarchyId)
        if (!hierarchyId) return
        const card = list.closest("[data-hierarchy-card]")
        const expectedType = card?.dataset.hierarchyScope === "division" ? "Division" : "SubDivision"
        list.querySelectorAll("[data-owner-id]").forEach((owner) => {
          const ownerId = Number(owner.dataset.ownerId)
          if (!ownerId || !owner.dataset.ownerType) return
          if (owner.dataset.ownerType !== expectedType) return
          reattachments.push({
            owner_type: owner.dataset.ownerType,
            owner_id: ownerId,
            hierarchy_id: hierarchyId
          })
        })
      })

      this.element.dispatchEvent(new CustomEvent("unsaved-changes:snapshot", {
        bubbles: true,
        detail: { snapshot: JSON.stringify({ hierarchies, reattachments }), seedInitial: true }
      }))

      this.payloadTarget.value = JSON.stringify({ hierarchies, reattachments, deleted_hierarchy_ids: [] })

      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const tokenInput = this.formTarget.querySelector('input[name="authenticity_token"]')
      if (token && tokenInput) tokenInput.value = token

      if (typeof this.formTarget.requestSubmit === "function") {
        this.formTarget.requestSubmit()
      } else {
        this.formTarget.submit()
      }
    } catch (error) {
      console.error(error)
      fail("Could not prepare the save payload. Refresh and try again.")
    }
  }
}
