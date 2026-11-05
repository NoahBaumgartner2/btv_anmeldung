import { Controller } from "@hotwired/stimulus"

// Zeigt das gewählte Kursfoto sofort als Vorschau, noch vor dem Speichern.
export default class extends Controller {
  static targets = ["image", "placeholder", "note"]

  show(event) {
    const file = event.target.files[0]
    if (!file) return
    this.imageTarget.src = URL.createObjectURL(file)
    this.imageTarget.classList.remove("hidden")
    this.placeholderTarget.classList.add("hidden")
    if (this.hasNoteTarget) this.noteTarget.classList.add("hidden")
  }
}
