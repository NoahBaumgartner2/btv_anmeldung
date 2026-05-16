import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["priceField"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.element.querySelector("input[name='course[has_payment]']:checked")
    if (!this.hasPriceFieldTarget) return
    const show = selected && selected.value === "true"
    this.priceFieldTarget.classList.toggle("hidden", !show)
  }
}
