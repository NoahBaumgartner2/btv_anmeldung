import { Controller } from "@hotwired/stimulus"

// Steuert das "Training verwalten"-Modal auf training_sessions/show.html.erb:
// Tab-Wechsel zwischen "Absagen" und "Ersatztrainer", sowie die client-seitige
// Suche/Auswahl in der Ersatztrainer-Liste (Trainerzahl ist klein genug für
// reines JS-Filtern, kein Server-Roundtrip nötig).
export default class extends Controller {
  static targets = [
    "cancelTab", "substituteTab", "cancelPanel", "substitutePanel",
    "trainerSearch", "trainerCard", "noResults",
    "selectedTrainerId", "reasonWrap"
  ]

  showCancel() {
    this.cancelPanelTarget.classList.remove("hidden")
    this.substitutePanelTarget.classList.add("hidden")
    this.cancelTabTarget.classList.replace("bg-gray-100", "bg-red-600")
    this.cancelTabTarget.classList.replace("text-gray-600", "text-white")
    this.substituteTabTarget.classList.replace("bg-primary-600", "bg-gray-100")
    this.substituteTabTarget.classList.replace("text-white", "text-gray-600")
  }

  showSubstitute() {
    this.substitutePanelTarget.classList.remove("hidden")
    this.cancelPanelTarget.classList.add("hidden")
    this.substituteTabTarget.classList.replace("bg-gray-100", "bg-primary-600")
    this.substituteTabTarget.classList.replace("text-gray-600", "text-white")
    this.cancelTabTarget.classList.replace("bg-red-600", "bg-gray-100")
    this.cancelTabTarget.classList.replace("text-white", "text-gray-600")
  }

  filterTrainers() {
    const q = this.trainerSearchTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.trainerCardTargets.forEach((card) => {
      const match = !q || card.dataset.searchBlob.includes(q)
      card.classList.toggle("hidden", !match)
      if (match) visibleCount++
    })

    this.noResultsTarget.classList.toggle("hidden", visibleCount > 0)
  }

  selectTrainer(event) {
    const card = event.currentTarget
    this.selectedTrainerIdTarget.value = card.dataset.trainerId

    this.trainerCardTargets.forEach((c) => {
      c.classList.remove("ring-2", "ring-primary-500", "bg-primary-50")
    })
    card.classList.add("ring-2", "ring-primary-500", "bg-primary-50")

    this.reasonWrapTarget.classList.remove("hidden")
  }
}
