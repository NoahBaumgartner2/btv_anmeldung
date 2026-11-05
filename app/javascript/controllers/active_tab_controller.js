import { Controller } from "@hotwired/stimulus"

// Scrollt in einer seitlich scrollbaren Tab-Leiste den aktiven Tab (aria-current="page")
// in die Mitte, damit er auf dem Handy sichtbar ist. Nur die Leiste scrollt, nicht die Seite.
export default class extends Controller {
  connect() {
    const active = this.element.querySelector('[aria-current="page"]')
    if (!active) return

    const left = active.offsetLeft - (this.element.clientWidth - active.offsetWidth) / 2
    this.element.scrollLeft = Math.max(0, left)
  }
}
