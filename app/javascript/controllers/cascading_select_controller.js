import { Controller } from "@hotwired/stimulus"

// Drives the Division → SubDivision → Category cascade from a JSON tree
// embedded in the page, so no requests are needed between steps.
export default class extends Controller {
  static targets = ["division", "subDivision", "category", "polarityNote"]
  static values = { tree: Array }

  connect() {
    // Restore downstream options when re-rendering a failed submission.
    this.populateSubDivisions(this.subDivisionTarget.dataset.selected)
    this.populateCategories(this.categoryTarget.dataset.selected)
    this.updatePolarityNote()
  }

  divisionChanged() {
    this.populateSubDivisions()
    this.populateCategories()
    this.updatePolarityNote()
  }

  subDivisionChanged() {
    this.populateCategories()
  }

  populateSubDivisions(selectedId = null) {
    const division = this.selectedDivision()
    const subDivisions = division ? division.subDivisions : []
    this.fillSelect(this.subDivisionTarget, "Select a sub-division", subDivisions.map((sd) => [sd.id, sd.name]), selectedId)
  }

  populateCategories(selectedId = null) {
    const subDivision = this.selectedSubDivision()
    const categories = subDivision ? subDivision.categories : []
    this.fillSelect(
      this.categoryTarget,
      "Select a category",
      categories.map((c) => [c.id, `${c.name} (${c.points} pts)`]),
      selectedId
    )
  }

  updatePolarityNote() {
    const division = this.selectedDivision()
    if (!division) {
      this.polarityNoteTarget.textContent = ""
      return
    }
    this.polarityNoteTarget.textContent =
      division.divType === "positive"
        ? "Positive division — approved requests add points."
        : "Negative division — approved requests deduct points."
  }

  selectedDivision() {
    return this.treeValue.find((d) => String(d.id) === this.divisionTarget.value)
  }

  selectedSubDivision() {
    const division = this.selectedDivision()
    if (!division) return null
    return division.subDivisions.find((sd) => String(sd.id) === this.subDivisionTarget.value)
  }

  fillSelect(select, prompt, options, selectedId) {
    select.innerHTML = ""
    select.appendChild(new Option(prompt, ""))
    for (const [id, label] of options) {
      select.appendChild(new Option(label, id, false, String(id) === String(selectedId)))
    }
  }
}
