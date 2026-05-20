import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  togglePermission(event) {
    const trainerId = event.currentTarget.dataset.trainerId
    const permsDiv = document.getElementById(`trainer-perms-${trainerId}`)
    if (!permsDiv) return

    if (event.currentTarget.checked) {
      permsDiv.classList.remove("hidden")
    } else {
      permsDiv.classList.add("hidden")
      const permCheckbox = permsDiv.querySelector("input[type=checkbox]")
      if (permCheckbox) permCheckbox.checked = false
    }
  }
}
