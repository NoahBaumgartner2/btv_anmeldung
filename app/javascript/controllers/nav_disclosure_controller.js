import { Controller } from "@hotwired/stimulus"

// Aufklappbarer Navigationseintrag (Sidebar › Admin-Dashboard). Die Animation
// macht CSS über [data-open] (.nav-sub); geschlossen ist das Panel inert, damit
// Tastatur und Screenreader die verborgenen Links überspringen.
// Turbo rendert die Sidebar bei jedem Besuch neu: war sie vorher schon offen,
// sofort offen; kommt man von zu (Klick auf „Admin-Dashboard“), animiert aufklappen.
let wasOpen // überlebt Turbo-Besuche (Modul bleibt geladen)

export default class extends Controller {
  static targets = ["button", "panel"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue && wasOpen === false) {
      this.apply(false)
      requestAnimationFrame(() => requestAnimationFrame(() => this.apply(true)))
    } else {
      this.apply(this.openValue)
    }
  }

  toggle() {
    this.apply(!this.element.hasAttribute("data-open"))
  }

  apply(open) {
    wasOpen = open
    this.element.toggleAttribute("data-open", open)
    this.buttonTarget.setAttribute("aria-expanded", open)
    this.panelTarget.inert = !open
  }
}
