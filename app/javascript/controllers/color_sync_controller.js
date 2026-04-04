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

  // Farbpalette → Textfeld
  pickerTargetConnected(picker) {
    this.textTarget.value = picker.value
    picker.addEventListener("input", () => {
      this.textTarget.value = picker.value
    })
  }

  // Textfeld → Farbpalette (nur bei gültigem Hex-Wert)
  textTargetConnected(text) {
    text.addEventListener("input", () => {
      if (/^#[0-9A-Fa-f]{6}$/.test(text.value)) {
        this.pickerTarget.value = text.value
      }
    })
  }
}
