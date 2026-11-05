import { Controller } from "@hotwired/stimulus"

// Trainer-Zuweisung im Kursformular: Berechtigung ein-/ausblenden, Liste durchsuchen,
// Anzahl zugewiesener Trainer:innen anzeigen.
export default class extends Controller {
  static targets = ["query", "row", "count", "empty"]

  connect() {
    this.updateCount()
  }

  togglePermission(event) {
    const trainerId = event.currentTarget.dataset.trainerId
    const permsDiv = document.getElementById(`trainer-perms-${trainerId}`)
    if (permsDiv) {
      if (event.currentTarget.checked) {
        permsDiv.classList.remove("hidden")
      } else {
        permsDiv.classList.add("hidden")
        const permCheckbox = permsDiv.querySelector("input[type=checkbox]")
        if (permCheckbox) permCheckbox.checked = false
      }
    }
    this.updateCount()
  }

  filter() {
    const query = this.queryTarget.value.trim().toLowerCase()
    let visible = 0
    this.rowTargets.forEach((row) => {
      const match = query === "" || row.dataset.search.includes(query)
      row.hidden = !match
      if (match) visible++
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
  }

  updateCount() {
    if (!this.hasCountTarget) return
    const assigned = this.element.querySelectorAll('input[name="course[trainer_ids][]"]:checked').length
    this.countTarget.textContent = this.countTarget.dataset.template.replace("%{count}", assigned)
  }
}
