import { Controller } from "@hotwired/stimulus"

// Aktiviert den Newsletter- und Foto-Einverständnis-Checkbox automatisch wenn
// die Datenschutz-Checkbox angehakt wird. Beide Checkboxen bleiben unabhängig
// abwählbar. Wird die Datenschutz-Checkbox deaktiviert, werden auch sie deaktiviert.
export default class extends Controller {
  static targets = ["privacy", "newsletter", "photo"]

  privacyChanged() {
    const checked = this.privacyTarget.checked
    this.newsletterTarget.checked = checked
    if (this.hasPhotoTarget) {
      this.photoTarget.checked = checked
    }
  }
}
