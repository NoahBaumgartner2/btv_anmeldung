import { Controller } from "@hotwired/stimulus"

// Aufklappbarer Navigationseintrag (Sidebar › Admin-Dashboard). Die Animation
// macht CSS über [data-open] (.nav-sub); geschlossen ist das Panel inert, damit
// Tastatur und Screenreader die verborgenen Links überspringen.
export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.apply(this.element.hasAttribute("data-open"))
  }

  toggle() {
    this.apply(!this.element.hasAttribute("data-open"))
  }

  apply(open) {
    this.element.toggleAttribute("data-open", open)
    this.buttonTarget.setAttribute("aria-expanded", open)
    this.panelTarget.inert = !open
  }
}
