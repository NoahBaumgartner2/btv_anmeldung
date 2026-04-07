import { Controller } from "@hotwired/stimulus"

// Synchronisiert ein nativer <input type="color"> (Farbpalette) mit einem
// <input type="text"> (Hex-Wert) in beide Richtungen.
//
// Verwendung:
//   <div data-controller="color-sync">
//     <input type="color" data-color-sync-target="picker">
//     <input type="text"  data-color-sync-target="text">
//   </div>

export default class extends Controller {
  static targets = ["picker", "text"]

  connect() {
    // Initialer Sync: Textfeld auf Picker-Wert setzen
    this.textTarget.value = this.pickerTarget.value

    // Farbpalette → Textfeld
    this.pickerTarget.addEventListener("input", () => {
      this.textTarget.value = this.pickerTarget.value
    })

    // Textfeld → Farbpalette (nur bei gültigem Hex-Wert)
    this.textTarget.addEventListener("input", () => {
      if (/^#[0-9A-Fa-f]{6}$/.test(this.textTarget.value)) {
        this.pickerTarget.value = this.textTarget.value
      }
    })
  }
}
