import { Controller } from "@hotwired/stimulus"

// Kursübersicht: Kategorie-Kacheln öffnen ein <dialog> mit allen Kursen.
// Der Filter blendet Kurse nach Wochentag/Ort aus (innerhalb einer Gruppe ODER,
// zwischen den Gruppen UND) und Kacheln ohne Treffer ganz.
export default class extends Controller {
  static targets = ["card", "group", "chip", "empty", "status", "count"]

  // Link von der Startseite (/courses#kategorie) öffnet das Overlay direkt.
  connect() {
    const id = decodeURIComponent(window.location.hash.slice(1))
    if (id) document.getElementById(id)?.querySelector("dialog")?.showModal()
  }

  open({ params: { dialog } }) {
    document.getElementById(dialog).showModal()
  }

  // Klick auf den Hintergrund (das <dialog> selbst, nicht sein Inhalt) schliesst.
  backdropClose(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }

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
      const count = this.cardTargets.filter((card) => !card.hidden && group.contains(card)).length
      group.hidden = count === 0
      const badge = group.querySelector("[data-group-count]")
      if (badge) badge.textContent = (count === 1 ? badge.dataset.one : badge.dataset.other).replace("%{count}", count)
    })

    const active = days.length + locations.length > 0
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
    if (this.hasStatusTarget) this.statusTarget.hidden = !active
    if (this.hasCountTarget) this.countTarget.textContent = this.countTarget.dataset.template
      .replace("%{visible}", visible).replace("%{total}", this.cardTargets.length)
  }
}
