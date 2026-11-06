import { Controller } from "@hotwired/stimulus"

// Öffnet ein natives <dialog> als Overlay; Klick auf den Hintergrund schliesst.
// Schliessen per Esc oder <form method="dialog"> macht der Browser selbst.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  backdropClose(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }
}
