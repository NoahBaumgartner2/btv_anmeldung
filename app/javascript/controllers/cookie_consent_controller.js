import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "cookie_consent"

export default class extends Controller {
  connect() {
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
    localStorage.setItem(STORAGE_KEY, value)
    this.element.remove()
  }
}
