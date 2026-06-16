import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dob", "ahvField", "ahvLabel", "ahvHint"]

  connect() {
    this.update()
  }

  update() {
    const dob = this.dobTarget.value
    const isMinor = dob ? this.#calculateIsMinor(dob) : false
    this.ahvFieldTarget.required = isMinor
    this.ahvLabelTarget.textContent = isMinor
      ? this.ahvLabelTarget.dataset.labelRequired
      : this.ahvLabelTarget.dataset.labelOptional
    this.ahvHintTarget.textContent = isMinor
      ? this.ahvHintTarget.dataset.hintRequired
      : this.ahvHintTarget.dataset.hintOptional
  }

  #calculateIsMinor(dobString) {
    const today = new Date()
    const dob = new Date(dobString)
    let age = today.getFullYear() - dob.getFullYear()
    const hadBirthday =
      today.getMonth() > dob.getMonth() ||
      (today.getMonth() === dob.getMonth() && today.getDate() >= dob.getDate())
    if (!hadBirthday) age--
    return age < 18
  }
}
