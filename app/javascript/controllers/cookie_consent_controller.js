import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "cookie_consent"

export default class extends Controller {
  static values = { url: String }

  connect() {
    // Fallback: falls doch noch ein localStorage-Wert existiert, Banner sofort entfernen
    if (localStorage.getItem(STORAGE_KEY)) {
      this.element.remove()
    }
  }

  acceptNecessary() {
    this._save("necessary")
  }

  acceptAll() {
    this._save("all")
  }

  _save(value) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrf
      },
      body: `consent=${value}`
    }).then(() => {
      localStorage.setItem(STORAGE_KEY, value) // Fallback für nächsten Page-Load
      this.element.remove()
    })
  }
}
