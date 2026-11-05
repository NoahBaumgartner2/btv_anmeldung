import { Controller } from "@hotwired/stimulus"

// Kursübersicht: Kategorie-Kacheln öffnen ein <dialog> mit allen Kursen.
// Der Filter blendet Kurse nach Wochentag/Ort aus (innerhalb einer Gruppe ODER,
// zwischen den Gruppen UND) und Kacheln ohne Treffer ganz.
export default class extends Controller {
  static targets = ["card", "group", "chip", "location", "empty", "status", "count"]

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
    if (this.hasLocationTarget) this.locationTarget.value = ""
    this.apply()
  }

  apply() {
    const selected = (key) => this.chipTargets
      .filter((c) => c.dataset.key === key && c.getAttribute("aria-pressed") === "true")
      .map((c) => c.dataset.value)
    const days = selected("weekday")
    const locations = this.hasLocationTarget && this.locationTarget.value ? [ this.locationTarget.value ] : []

    // Tag-Leiste im Overlay wirkt nur auf die Kurse dieses Overlays.
    const dialogDays = (card) => Array.from(card.closest("dialog")?.querySelectorAll(
      "[data-key=dialog-weekday][aria-pressed=true]") || []).map((c) => c.dataset.value)

    let visible = 0
    const globalMatch = new Set()
    this.cardTargets.forEach((card) => {
      const weekdays = card.dataset.weekdays.split(" ")
      const dayOk = days.length === 0 || weekdays.some((d) => days.includes(d))
      const locationOk = locations.length === 0 || locations.includes(card.dataset.location)
      const inDialog = dialogDays(card)
      const dialogOk = inDialog.length === 0 || weekdays.some((d) => inDialog.includes(d))
      if (dayOk && locationOk) { globalMatch.add(card); visible++ }
      card.hidden = !(dayOk && locationOk && dialogOk)
    })
    this.groupTargets.forEach((group) => {
      const count = this.cardTargets.filter((card) => globalMatch.has(card) && group.contains(card)).length
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
