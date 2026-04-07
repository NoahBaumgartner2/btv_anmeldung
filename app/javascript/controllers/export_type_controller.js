import { Controller } from "@hotwired/stimulus"

// Steuert die dynamische Formular-Logik für Exportprofile:
// – Blendet Sektionen je nach export_type (Teilnehmerliste / Anwesenheitsliste) ein/aus
// – Blendet CSV-Optionen je nach gewähltem Format ein/aus
// – Blendet Datumsfelder je nach Zeitraum-Typ ein/aus
export default class extends Controller {
  static targets = [
    "teilnehmerSection",
    "anwesenheitSection",
    "csvSection",
    "dateCustomSection"
  ]

  connect() {
    this.toggleExportType()
    this.toggleFormat()
    this.toggleDateRange()
  }

  toggleExportType() {
    const checked = this.element.querySelector('input[name="export_profile[export_type]"]:checked')
    const type = checked?.value

    this.teilnehmerSectionTargets.forEach(el =>
      el.classList.toggle("hidden", type !== "teilnehmerliste")
    )
    this.anwesenheitSectionTargets.forEach(el =>
      el.classList.toggle("hidden", type !== "anwesenheitsliste")
    )
  }

  toggleFormat() {
    const checked = this.element.querySelector('input[name="export_profile[format]"]:checked')
    const format = checked?.value

    this.csvSectionTargets.forEach(el =>
      el.classList.toggle("hidden", format !== "csv")
    )
  }

  toggleDateRange() {
    const checked = this.element.querySelector('input[name="export_profile[date_range_type]"]:checked')
    const type = checked?.value

    this.dateCustomSectionTargets.forEach(el =>
      el.classList.toggle("hidden", type !== "custom")
    )
  }
}
