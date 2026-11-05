import { Controller } from "@hotwired/stimulus"

// Kursübersicht: filtert die Karten nach Wochentag und Ort. Innerhalb einer
// Gruppe gilt ODER (Mo oder Mi), zwischen den Gruppen UND (Mo und Halle X).
export default class extends Controller {
  static targets = ["card", "group", "chip", "empty", "status", "count"]

  toggle(event) {
    const chip = event.currentTarget
    chip.setAttribute("aria-pressed", chip.getAttribute("aria-pressed") !== "true")
    this.apply()
  }

  reset() {
    this.chipTargets.forEach((chip) => chip.setAttribute("aria-pressed", "false"))
    this.apply()
  }

  apply() {
    const selected = (key) => this.chipTargets
      .filter((c) => c.dataset.key === key && c.getAttribute("aria-pressed") === "true")
      .map((c) => c.dataset.value)
    const days = selected("weekday")
    const locations = selected("location")

    let visible = 0
    this.cardTargets.forEach((card) => {
      const dayOk = days.length === 0 || card.dataset.weekdays.split(" ").some((d) => days.includes(d))
      const locationOk = locations.length === 0 || locations.includes(card.dataset.location)
      card.hidden = !(dayOk && locationOk)
      if (!card.hidden) visible++
    })
    this.groupTargets.forEach((group) => {
      group.hidden = !this.cardTargets.some((card) => !card.hidden && group.contains(card))
    })

    const active = days.length + locations.length > 0
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
    if (this.hasStatusTarget) this.statusTarget.hidden = !active
    if (this.hasCountTarget) this.countTarget.textContent = this.countTarget.dataset.template
      .replace("%{visible}", visible).replace("%{total}", this.cardTargets.length)
  }
}
