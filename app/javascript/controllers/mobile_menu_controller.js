import { Controller } from "@hotwired/stimulus"

// Steuert das Hamburger-Mobile-Menü in der Hauptnavigation (application.html.erb).
//
// Verhalten:
//   - Klick auf Hamburger-Button toggelt das Panel.
//   - Klick außerhalb der Navigation oder auf einen Link im Panel schließt es.
//   - Escape-Taste schließt es ebenfalls.
//   - Animation läuft nur über class-Toggles (keine inline-styles → CSP-konform).
//
// Markup-Vertrag:
//   <nav data-controller="mobile-menu"
//        data-action="click@window->mobile-menu#closeOnOutside
//                     keydown@window->mobile-menu#closeOnEscape">
//     <button data-mobile-menu-target="button"
//             data-action="click->mobile-menu#toggle"
//             aria-expanded="false">
//       <svg data-mobile-menu-target="iconOpen">…</svg>
//       <svg data-mobile-menu-target="iconClose" class="hidden">…</svg>
//     </button>
//     <div data-mobile-menu-target="panel"
//          class="… max-h-0 opacity-0 pointer-events-none …">
//       <a data-action="click->mobile-menu#close">…</a>
//     </div>
//   </nav>
export default class extends Controller {
  static targets = ["panel", "button", "iconOpen", "iconClose"]

  open() {
    this.panelTarget.classList.remove("max-h-0", "opacity-0", "pointer-events-none")
    this.panelTarget.classList.add("max-h-96", "opacity-100")
    this.iconOpenTarget.classList.add("hidden")
    this.iconCloseTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.panelTarget.classList.add("max-h-0", "opacity-0", "pointer-events-none")
    this.panelTarget.classList.remove("max-h-96", "opacity-100")
    this.iconOpenTarget.classList.remove("hidden")
    this.iconCloseTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  closeOnOutside(event) {
    if (!this.isOpen) return
    if (this.element.contains(event.target)) return
    this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.close()
    }
  }

  get isOpen() {
    return !this.panelTarget.classList.contains("max-h-0")
  }
}
