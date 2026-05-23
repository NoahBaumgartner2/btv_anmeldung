import { Controller } from "@hotwired/stimulus"

// Zeigt/versteckt ein Passwortfeld beim Klick auf den Auge-Button.
export default class extends Controller {
  static targets = ["field", "eyeShow", "eyeHide"]

  toggle() {
    const isPassword = this.fieldTarget.type === "password"
    this.fieldTarget.type = isPassword ? "text" : "password"
    this.eyeShowTarget.classList.toggle("hidden", isPassword)
    this.eyeHideTarget.classList.toggle("hidden", !isPassword)
  }
}
