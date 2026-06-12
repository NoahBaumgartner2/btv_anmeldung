import { Controller } from "@hotwired/stimulus"

// Blendet die Rabattpreis-Felder ein/aus je nach Checkbox "Preisreduktion aktivieren".
export default class extends Controller {
  static targets = ["checkbox", "fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasCheckboxTarget || !this.hasFieldsTarget) return
    this.fieldsTarget.classList.toggle("hidden", !this.checkboxTarget.checked)
  }
}
