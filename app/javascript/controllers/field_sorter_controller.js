import { Controller } from "@hotwired/stimulus"

// Ermöglicht das Umsortieren der Export-Felder per Up/Down-Pfeile.
// Die Reihenfolge der Felder bestimmt die Spaltenreihenfolge im CSV.
export default class extends Controller {
  static targets = ["row"]

  moveUp(event) {
    const row = event.currentTarget.closest("[data-field-sorter-target='row']")
    const prev = row.previousElementSibling
    if (prev) row.parentNode.insertBefore(row, prev)
  }

  moveDown(event) {
    const row = event.currentTarget.closest("[data-field-sorter-target='row']")
    const next = row.nextElementSibling
    if (next) row.parentNode.insertBefore(next, row)
  }
}
