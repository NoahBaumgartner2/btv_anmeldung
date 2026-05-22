import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._outsideClickHandler = this._onOutsideClick.bind(this)
    document.addEventListener("click", this._outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClickHandler)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }

  // Opens a modal dialog by its DOM id and closes the dropdown.
  // The dropdown item must have data-dialog-id="<id-of-the-dialog-element>".
  openDialog(event) {
    const id = event.currentTarget.dataset.dialogId
    const el = document.getElementById(id)
    if (el) {
      el.classList.remove("hidden")
      el.classList.add("flex")
    }
    this.close()
  }

  _onOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}
