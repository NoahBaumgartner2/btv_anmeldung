import { Controller } from "@hotwired/stimulus"

// Aktiviert das Foto-Einverständnis-Checkbox automatisch wenn die
// Datenschutz-Checkbox angehakt wird. Die Checkbox bleibt unabhängig
// abwählbar. Wird die Datenschutz-Checkbox deaktiviert, wird sie auch deaktiviert.
export default class extends Controller {
  static targets = ["privacy", "photo"]

  privacyChanged() {
    const checked = this.privacyTarget.checked
    if (this.hasPhotoTarget) {
      this.photoTarget.checked = checked
    }
  }
}
