import { Controller } from "@hotwired/stimulus"

// Shows the student-profile fieldset only when the selected role is "student".
export default class extends Controller {
  static targets = ["roleSelect", "studentFields"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.studentFieldsTarget.hidden = this.roleSelectTarget.value !== "student"
  }
}
