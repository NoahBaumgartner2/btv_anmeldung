import { Controller } from "@hotwired/stimulus"

// Generischer Modal-Controller: ein Trigger-Button öffnet einen Dialog,
// Klick auf den Hintergrund oder einen Close-Button schließt ihn wieder.
//
// Markup:
//   <div data-controller="modal" class="contents">
//     <button data-action="click->modal#open">Öffnen</button>
//     <div data-modal-target="dialog"
//          data-action="click->modal#backdropClose"
//          class="hidden fixed inset-0 ...">
//       <div> ...Inhalt... <button data-action="click->modal#close">Schließen</button> </div>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.classList.remove("hidden")
    this.dialogTarget.classList.add("flex")
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    this.dialogTarget.classList.remove("flex")
  }

  // Schließt nur, wenn der Klick direkt auf das Backdrop ging – nicht auf
  // ein Element innerhalb des Modal-Inhalts.
  backdropClose(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }
}
