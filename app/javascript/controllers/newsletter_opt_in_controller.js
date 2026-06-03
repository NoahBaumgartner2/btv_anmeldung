import { Controller } from "@hotwired/stimulus"

// Aktiviert den Newsletter-Checkbox automatisch wenn die Datenschutz-Checkbox
// angehakt wird. Der Newsletter-Checkbox bleibt unabhängig abwählbar.
// Wird die Datenschutz-Checkbox deaktiviert, wird auch der Newsletter deaktiviert.
export default class extends Controller {
  static targets = ["privacy", "newsletter"]

  privacyChanged() {
    if (this.privacyTarget.checked) {
      this.newsletterTarget.checked = true
    } else {
      this.newsletterTarget.checked = false
    }
  }
}
