import { Controller } from "@hotwired/stimulus"

// Blendet je nach gewähltem Modus entweder das Term-Feld (Semester/Quartal,
// Start-/Enddatum werden vom Term übernommen) oder manuelle Start-/Enddatum-
// Felder ein. Beim Wechsel auf "manuell" wird der Term geleert, beim Wechsel
// auf "Term" bzw. bei Termauswahl werden die Datumsfelder aus dem Term befüllt.
export default class extends Controller {
  static targets = ["radio", "termFields", "manualFields", "termSelect", "startDate", "endDate"]

  connect() {
    this.toggle()
  }

  toggle() {
    const checked = this.radioTargets.find((r) => r.checked)
    const isTerm = !checked || checked.value === "term"

    this.termFieldsTarget.classList.toggle("hidden", !isTerm)
    this.manualFieldsTarget.classList.toggle("hidden", isTerm)

    if (isTerm) {
      this.syncDates()
    } else if (this.hasTermSelectTarget) {
      this.termSelectTarget.value = ""
    }
  }

  syncDates() {
    if (!this.hasTermSelectTarget) return
    const option = this.termSelectTarget.selectedOptions[0]
    this.startDateTarget.value = option?.dataset.start || ""
    this.endDateTarget.value = option?.dataset.end || ""
  }
}
