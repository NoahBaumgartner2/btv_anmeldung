import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "button"]

  connect() {
    this._activate("all")
  }

  select(event) {
    const weekday = event.currentTarget.dataset.weekday
    this._activate(weekday)
  }

  _activate(weekday) {
    this.sectionTargets.forEach(section => {
      if (weekday === "all" || section.dataset.weekday === weekday) {
        section.classList.remove("hidden")
      } else {
        section.classList.add("hidden")
      }
    })

    this.buttonTargets.forEach(btn => {
      if (btn.dataset.weekday === weekday) {
        btn.classList.add("bg-primary-600", "text-white")
        btn.classList.remove("bg-white", "text-gray-700", "hover:bg-gray-50")
      } else {
        btn.classList.remove("bg-primary-600", "text-white")
        btn.classList.add("bg-white", "text-gray-700", "hover:bg-gray-50")
      }
    })
  }
}
