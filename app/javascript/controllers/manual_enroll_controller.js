import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchTab", "createTab", "searchPanel", "createPanel",
                    "searchInput", "searchResults", "participantId", "enrollForm",
                    "trialCheckbox", "trialSessionSelect", "trialField", "trialSessionField"]

  showSearch() {
    this.searchPanelTarget.classList.remove("hidden")
    this.createPanelTarget.classList.add("hidden")
    this.searchTabTarget.classList.replace("bg-gray-100", "bg-primary-600")
    this.searchTabTarget.classList.replace("text-gray-600", "text-white")
    this.createTabTarget.classList.replace("bg-primary-600", "bg-gray-100")
    this.createTabTarget.classList.replace("text-white", "text-gray-600")
  }

  showCreate() {
    this.createPanelTarget.classList.remove("hidden")
    this.searchPanelTarget.classList.add("hidden")
    this.createTabTarget.classList.replace("bg-gray-100", "bg-primary-600")
    this.createTabTarget.classList.replace("text-gray-600", "text-white")
    this.searchTabTarget.classList.replace("bg-primary-600", "bg-gray-100")
    this.searchTabTarget.classList.replace("text-white", "text-gray-600")
  }

  async search() {
    const q = this.searchInputTarget.value.trim()
    if (q.length < 2) {
      this.searchResultsTarget.innerHTML = ""
      return
    }

    const courseId = window.location.pathname.match(/\/courses\/(\d+)/)?.[1]
    const response = await fetch(`/courses/${courseId}/participant_search?q=${encodeURIComponent(q)}`, {
      headers: { "Accept": "application/json" }
    })
    const results = await response.json()

    if (results.length === 0) {
      this.searchResultsTarget.innerHTML = `
        <p class="text-sm text-gray-400 text-center py-3">Keine Ergebnisse für "${q}"</p>`
      return
    }

    this.searchResultsTarget.innerHTML = results.map(p => `
      <div class="flex items-center justify-between gap-3 p-3 bg-gray-50 rounded-lg border border-gray-200">
        <div class="min-w-0">
          <p class="text-sm font-bold text-gray-900">${p.name}</p>
          <p class="text-xs text-gray-500">${p.date_of_birth ? `Geb. ${p.date_of_birth}` : ""} ${p.email ? `· ${p.email}` : ""}</p>
        </div>
        ${p.already_registered
          ? `<span class="text-xs font-bold text-green-700 bg-green-100 px-2 py-1 rounded-md shrink-0">Bereits angemeldet</span>`
          : `<button type="button"
               data-participant-id="${p.id}"
               data-action="click->manual-enroll#enroll"
               class="shrink-0 bg-primary-600 hover:bg-primary-700 text-white text-xs font-bold py-1.5 px-3 rounded-lg transition cursor-pointer">
               Anmelden
             </button>`
        }
      </div>
    `).join("")
  }

  enroll(event) {
    const participantId = event.currentTarget.dataset.participantId
    const name = event.currentTarget.closest("div").querySelector("p.font-bold").textContent
    const verb = this.hasTrialCheckboxTarget && this.trialCheckboxTarget.checked ? "zum Schnuppern anmelden" : "für diesen Kurs anmelden"
    if (!confirm(`${name} ${verb}?`)) return

    this.participantIdTarget.value = participantId
    this.enrollFormTarget.submit()
  }

  toggleTrial() {
    const checked = this.trialCheckboxTarget.checked
    this.trialFieldTargets.forEach(f => f.value = checked ? "true" : "false")
    if (this.hasTrialSessionSelectTarget) {
      this.trialSessionSelectTarget.closest("div").classList.toggle("hidden", !checked)
    }
    this.syncTrialSession()
  }

  syncTrialSession() {
    const val = (this.hasTrialSessionSelectTarget && this.trialCheckboxTarget.checked)
      ? this.trialSessionSelectTarget.value : ""
    this.trialSessionFieldTargets.forEach(f => f.value = val)
  }
}
