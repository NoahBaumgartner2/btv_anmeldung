import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]
  static values  = { courseName: String }

  open(event) {
    event.preventDefault()
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
  }

  confirm() {
    this.element.querySelector("form[data-unsubscribe-form]").requestSubmit()
  }
}
