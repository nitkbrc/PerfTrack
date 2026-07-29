import { Controller } from "@hotwired/stimulus"

// Drives the 3-step raise-request wizard:
//   Step 1: polarity selection (Achievement vs Conduct)
//   Step 2: hierarchical card picker (Division → Sub-division → Category)
//   Step 3: details form with category pre-set from Step 2
//
// Division tree JSON is embedded once in the page — no network round-trips
// between picker levels. Divisions are filtered by the chosen polarity.

export default class extends Controller {
  static targets = [
    "step1",
    "step2",
    "step3",
    "progressStep",
    "progressConnector",
    "pickerBack",
    "pickerBreadcrumb",
    "pickerTitle",
    "pickerSubtitle",
    "pickerCards",
    "categoryIdField",
    "categorySummary",
    "summaryDivision",
    "summarySubDivision",
    "summaryCategory",
    "summaryBadge",
    "summaryPoints"
  ]
  static values = {
    tree: Array,
    step: { type: Number, default: 1 },
    polarity: String
  }

  connect() {
    this.pickerLevel = 0
    this.selectedDivision = null
    this.selectedSubDivision = null
    this.selectedCategory = null

    this.showStep(this.stepValue)

    if (this.stepValue === 2) {
      this.renderPicker()
    } else if (this.stepValue === 3) {
      this.restorePickerFromCategory()
    }
  }

  selectPolarity(event) {
    this.polarityValue = event.currentTarget.dataset.polarity
    this.pickerLevel = 0
    this.selectedDivision = null
    this.selectedSubDivision = null
    this.selectedCategory = null
    this.goToStep(2)
    this.renderPicker()
  }

  selectDivision(event) {
    const id = event.currentTarget.dataset.id
    this.selectedDivision = this.filteredTree().find((d) => String(d.id) === id)
    this.selectedSubDivision = null
    this.selectedCategory = null
    this.pickerLevel = 1
    this.renderPicker()
  }

  selectSubDivision(event) {
    const id = event.currentTarget.dataset.id
    this.selectedSubDivision = this.selectedDivision.subDivisions.find((sd) => String(sd.id) === id)
    this.selectedCategory = null
    this.pickerLevel = 2
    this.renderPicker()
  }

  selectCategory(event) {
    const id = event.currentTarget.dataset.id
    this.selectedCategory = this.selectedSubDivision.categories.find((c) => String(c.id) === id)
    this.categoryIdFieldTarget.value = id
    this.updateCategorySummary()
    setTimeout(() => this.goToStep(3), 150)
  }

  pickerBack() {
    if (this.pickerLevel === 0) {
      this.goToStep(1)
      return
    }

    this.pickerLevel -= 1
    if (this.pickerLevel === 0) {
      this.selectedDivision = null
      this.selectedSubDivision = null
    } else if (this.pickerLevel === 1) {
      this.selectedSubDivision = null
    }
    this.renderPicker()
  }

  back() {
    this.restorePickerFromCategory()
    this.goToStep(2)
    this.renderPicker()
  }

  goToStep(n) {
    this.stepValue = n
    this.showStep(n)
  }

  showStep(n) {
    this.step1Target.classList.toggle("hidden", n !== 1)
    this.step2Target.classList.toggle("hidden", n !== 2)
    this.step3Target.classList.toggle("hidden", n !== 3)
    this.updateProgress(n)
  }

  updateProgress(n) {
    const COMPLETED = "#16a34a"
    const ACTIVE = "#2563eb"
    const UPCOMING_BG = "#ffffff"
    const UPCOMING_TEXT = "#94a3b8"

    this.progressStepTargets.forEach((stepEl, i) => {
      const step = i + 1
      const icon = stepEl.querySelector("[data-progress-icon]")
      const number = stepEl.querySelector("[data-progress-number]")
      const check = stepEl.querySelector("[data-progress-check]")
      const label = stepEl.querySelector("[data-progress-label]")

      const completed = step < n
      const active = step === n

      icon.classList.toggle("border-transparent", completed || active)
      icon.classList.toggle("text-white", completed || active)
      icon.classList.toggle("border-slate-200", !completed && !active)
      icon.classList.toggle("text-slate-400", !completed && !active)

      icon.style.backgroundColor = completed ? COMPLETED : active ? ACTIVE : UPCOMING_BG
      label.style.color = completed ? COMPLETED : active ? ACTIVE : UPCOMING_TEXT

      // Completed steps show only the tick; every other state shows its number.
      number.classList.toggle("hidden", completed)
      check.classList.toggle("hidden", !completed)
      if (completed) {
        number.setAttribute("aria-hidden", "true")
        check.removeAttribute("aria-hidden")
      } else {
        number.removeAttribute("aria-hidden")
        check.setAttribute("aria-hidden", "true")
      }
    })
  }

  filteredTree() {
    if (!this.hasPolarityValue) return []
    return this.treeValue.filter((d) => d.divType === this.polarityValue)
  }

  renderPicker() {
    this.updatePickerHeader()
    this.updateBreadcrumb()
    this.renderCards()
  }

  updatePickerHeader() {
    const titles = ["Choose a division", "Choose a sub-division", "Choose a category"]
    const subtitles = [
      this.polarityValue === "positive"
        ? "Select an achievement division."
        : "Select a conduct division.",
      `Under ${this.selectedDivision?.name ?? "division"}`,
      `Under ${this.selectedSubDivision?.name ?? "sub-division"}`
    ]

    this.pickerTitleTarget.textContent = titles[this.pickerLevel]
    this.pickerSubtitleTarget.textContent = subtitles[this.pickerLevel]
  }

  updateBreadcrumb() {
    const labels = ["Division", "Sub-division", "Category"]
    const parts = labels.map((label, i) => {
      let classes = "rounded-full px-2.5 py-0.5 font-medium text-slate-400"
      if (i < this.pickerLevel) classes = "rounded-full bg-slate-100 px-2.5 py-0.5 font-medium text-slate-600"
      if (i === this.pickerLevel) classes = "rounded-full bg-[#e0e0ff] px-2.5 py-0.5 font-semibold text-[#000666]"

      const separator = i > 0
        ? `<span class="mx-0.5 select-none text-slate-300" aria-hidden="true">/</span>`
        : ""
      return `${separator}<span class="${classes}">${this.escapeHtml(label)}</span>`
    })

    this.pickerBreadcrumbTarget.innerHTML = parts.join("")
  }

  renderCards() {
    const container = this.pickerCardsTarget

    if (this.pickerLevel === 0) {
      const divisions = this.filteredTree()
      container.innerHTML = divisions.length
        ? divisions.map((d) => this.divisionCardHtml(d)).join("")
        : this.emptyStateHtml("No divisions available for this request type.")
      return
    }

    if (this.pickerLevel === 1) {
      const subDivisions = this.selectedDivision?.subDivisions ?? []
      container.innerHTML = subDivisions.length
        ? subDivisions.map((sd) => this.subDivisionCardHtml(sd)).join("")
        : this.emptyStateHtml("No sub-divisions available for this division.")
      return
    }

    const categories = this.selectedSubDivision?.categories ?? []
    container.innerHTML = categories.length
      ? categories.map((c) => this.categoryCardHtml(c)).join("")
      : this.emptyStateHtml("No categories available for this sub-division.")
  }

  // Card chrome shared by all three picker levels so they read as one family.
  cardShellClass() {
    return [
      "clay-card flex w-full gap-3 rounded-xl p-4 text-left",
      "transition hover:border-[#000666]/30 hover:shadow-md cursor-pointer"
    ].join(" ")
  }

  cardIconClass(surface) {
    return `flex h-10 w-10 shrink-0 items-center justify-center rounded-lg ${surface}`
  }

  divisionCardHtml(division) {
    const isPositive = division.divType === "positive"
    const iconBg = isPositive ? "bg-green-50" : "bg-amber-50"
    const iconColor = isPositive ? "text-green-600" : "text-amber-700"
    const icon = isPositive ? "emoji_events" : "gavel"
    const count = division.subDivisions.length

    return `
      <button type="button"
              data-id="${division.id}"
              data-action="click->raise-wizard#selectDivision"
              class="${this.cardShellClass()}">
        <span class="${this.cardIconClass(iconBg)}">
          <span class="material-symbols-outlined text-[20px] ${iconColor}" aria-hidden="true">${icon}</span>
        </span>
        <span class="min-w-0 flex-1">
          <span class="block text-base font-bold leading-tight text-[#000666]">${this.escapeHtml(division.name)}</span>
          <span class="mt-1 block text-xs text-slate-500">${count} sub-division${count === 1 ? "" : "s"}</span>
        </span>
      </button>`
  }

  subDivisionCardHtml(subDivision) {
    const count = subDivision.categories.length
    return `
      <button type="button"
              data-id="${subDivision.id}"
              data-action="click->raise-wizard#selectSubDivision"
              class="${this.cardShellClass()}">
        <span class="${this.cardIconClass("bg-[#e0e0ff]")}">
          <span class="material-symbols-outlined text-[20px] text-[#000666]" aria-hidden="true">folder</span>
        </span>
        <span class="min-w-0 flex-1">
          <span class="block text-base font-bold leading-tight text-[#000666]">${this.escapeHtml(subDivision.name)}</span>
          <span class="mt-1 block text-xs text-slate-500">${count} categor${count === 1 ? "y" : "ies"}</span>
        </span>
      </button>`
  }

  // Category cards sit in a narrow two-column grid, so the icon and the points
  // pill share a header row and the title gets the full card width underneath.
  categoryCardHtml(category) {
    const pts = category.points
    const isPositive = pts >= 0
    const ptsLabel = isPositive ? `+${pts} pts` : `${pts} pts`
    const icon = isPositive ? "trending_up" : "trending_down"

    return `
      <button type="button"
              data-id="${category.id}"
              data-action="click->raise-wizard#selectCategory"
              class="${this.cardShellClass()} flex-col">
        <span class="flex items-center justify-between gap-2">
          <span class="${this.cardIconClass("bg-[#e0e0ff]")}">
            <span class="material-symbols-outlined text-[20px] text-[#000666]" aria-hidden="true">${icon}</span>
          </span>
          <span class="${this.badgePillClass(this.pointsBadgeTone(pts))}"
                style="font-variant-numeric: tabular-nums;">${ptsLabel}</span>
        </span>
        <span class="block text-base font-bold leading-tight text-[#000666]">${this.escapeHtml(category.name)}</span>
      </button>`
  }

  divisionTypeBadge(isPositive) {
    return isPositive
      ? { label: "Achievement", tone: "border-green-200 bg-green-50 text-green-700" }
      : { label: "Conduct", tone: "border-amber-300 bg-amber-50 text-amber-800" }
  }

  pointsBadgeTone(points) {
    return points >= 0
      ? "border-green-200 bg-green-50 text-green-700"
      : "border-red-200 bg-red-50 text-red-700"
  }

  badgePillClass(tone) {
    return [
      "inline-flex shrink-0 items-center rounded-full border px-2 py-0.5",
      "text-[10px] font-semibold uppercase tracking-wider whitespace-nowrap",
      tone
    ].join(" ")
  }

  emptyStateHtml(message) {
    return `<p class="col-span-full py-8 text-center text-sm text-slate-500">${this.escapeHtml(message)}</p>`
  }

  updateCategorySummary() {
    const division = this.selectedDivision
    const subDivision = this.selectedSubDivision
    const category = this.selectedCategory
    if (!division || !subDivision || !category) return

    this.summaryDivisionTarget.textContent = division.name
    this.summarySubDivisionTarget.textContent = subDivision.name
    this.summaryCategoryTarget.textContent = category.name
    this.summaryPointsTarget.textContent = `${category.points >= 0 ? "+" : ""}${category.points} pts`

    const isPositive = division.divType === "positive"
    const badge = this.divisionTypeBadge(isPositive)
    this.summaryBadgeTarget.textContent = badge.label
    this.summaryBadgeTarget.className = this.badgePillClass(badge.tone)

    const ptsTone = this.pointsBadgeTone(category.points)
    this.summaryPointsTarget.className = this.badgePillClass(ptsTone)

    this.categorySummaryTarget.classList.remove("hidden")
  }

  restorePickerFromCategory() {
    const categoryId = this.categoryIdFieldTarget?.value
    if (!categoryId) {
      this.pickerLevel = 0
      this.selectedDivision = null
      this.selectedSubDivision = null
      this.selectedCategory = null
      return
    }

    for (const division of this.treeValue) {
      for (const subDivision of division.subDivisions) {
        const category = subDivision.categories.find((c) => String(c.id) === String(categoryId))
        if (category) {
          this.polarityValue = division.divType
          this.selectedDivision = division
          this.selectedSubDivision = subDivision
          this.selectedCategory = category
          this.pickerLevel = 2
          return
        }
      }
    }
  }

  escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
