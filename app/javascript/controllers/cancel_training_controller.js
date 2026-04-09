import { Controller } from "@hotwired/stimulus"

// Steuert das Aufklappen des Bestätigungs-Panels für "Training absagen".
// Wird auf training_sessions/show.html.erb verwendet.
export default class extends Controller {
  static targets = ["trigger", "panel"]

  open() {
    this.panelTarget.classList.remove("hidden")
    this.triggerTarget.classList.add("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.triggerTarget.classList.remove("hidden")
  }
}
