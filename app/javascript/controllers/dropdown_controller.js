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
    const menu = this.menuTarget
    const isHidden = menu.classList.contains("hidden")

    if (isHidden) {
      const btn = this.element.querySelector("[data-action*='dropdown#toggle']")
      const rect = btn.getBoundingClientRect()
      menu.style.position = "fixed"
      menu.style.top = (rect.bottom + 4) + "px"
      menu.style.right = (window.innerWidth - rect.right) + "px"
      menu.style.left = "auto"
      menu.style.zIndex = "9999"
      menu.classList.remove("hidden")
    } else {
      menu.classList.add("hidden")
    }
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
