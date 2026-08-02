import { Controller } from "@hotwired/stimulus"

// Blendet das abo-size-field sowie Semester/Quartal & Start-/Enddatum
// ein/aus je nach gewähltem Anmeldemodus (Abo-Kurse sind durchgehend
// verfügbar und haben daher keinen Datumsbereich).
export default class extends Controller {
  static targets = ["aboField", "dateFields", "aboDateHint"]

  connect() {
    this.toggle()
  }

  toggle() {
    const select = this.element.querySelector("select[name='course[registration_mode]']")
    if (!select) return
    const isAbo = select.value === "abo"

    if (this.hasAboFieldTarget) this.aboFieldTarget.classList.toggle("hidden", !isAbo)
    if (this.hasDateFieldsTarget) this.dateFieldsTarget.classList.toggle("hidden", isAbo)
    if (this.hasAboDateHintTarget) this.aboDateHintTarget.classList.toggle("hidden", !isAbo)
  }
}
