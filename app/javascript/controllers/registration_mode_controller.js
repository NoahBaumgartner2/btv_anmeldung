import { Controller } from "@hotwired/stimulus"

// Blendet das abo-size-field ein/aus je nach gewähltem Anmeldemodus.
export default class extends Controller {
  static targets = ["aboField"]

  connect() {
    this.toggle()
  }

  toggle() {
    const select = this.element.querySelector("select[name='course[registration_mode]']")
    if (!select || !this.hasAboFieldTarget) return
    this.aboFieldTarget.classList.toggle("hidden", select.value !== "abo")
  }
}
