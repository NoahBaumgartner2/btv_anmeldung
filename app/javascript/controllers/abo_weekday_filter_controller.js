import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "button", "loadMore"]
  static values = { pageSize: { type: Number, default: 10 } }

  connect() {
    this.activeWeekday = "all"
    this.visibleCount = this.pageSizeValue
    this.render()
  }

  select(event) {
    this.activeWeekday = event.currentTarget.dataset.weekday
    this.visibleCount = this.pageSizeValue
    this._updateButtons()
    this.render()
  }

  loadMore() {
    this.visibleCount += this.pageSizeValue
    this.render()
  }

  render() {
    const matches = this.cardTargets.filter(card =>
      this.activeWeekday === "all" || card.dataset.weekday === this.activeWeekday
    )

    this.cardTargets.forEach(card => card.classList.add("hidden"))
    matches.slice(0, this.visibleCount).forEach(card => card.classList.remove("hidden"))

    if (this.hasLoadMoreTarget) {
      if (matches.length > this.visibleCount) {
        this.loadMoreTarget.classList.remove("hidden")
      } else {
        this.loadMoreTarget.classList.add("hidden")
      }
    }
  }

  _updateButtons() {
    this.buttonTargets.forEach(btn => {
      if (btn.dataset.weekday === this.activeWeekday) {
        btn.classList.add("bg-primary-600", "text-white")
        btn.classList.remove("bg-white", "text-gray-700", "hover:bg-gray-50")
      } else {
        btn.classList.remove("bg-primary-600", "text-white")
        btn.classList.add("bg-white", "text-gray-700", "hover:bg-gray-50")
      }
    })
  }
}
