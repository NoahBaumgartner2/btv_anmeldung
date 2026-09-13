import { Controller } from "@hotwired/stimulus"

// Kaskadierende Kursauswahl: Zeitraum (Term) -> Kategorie -> Kurs -> Teilnehmerliste.
// Bekommt die vollständige Kursliste und alle (nicht stornierten) Anmeldungen
// als JSON-Values und filtert client-seitig - kein Server-Roundtrip nötig, da
// die Listen pro Verein überschaubar bleiben. Sobald ein Kurs gewählt ist,
// zeigt participantsList genau dessen Teilnehmerliste zum Anhaken - bewusst
// keine freie Personensuche, damit nur tatsächlich angemeldete Personen
// ausgewählt werden können (siehe Admin::SupplementaryChargesController).
export default class extends Controller {
  static targets = ["termSelect", "categorySelect", "courseSelect", "participantsList"]
  static values = { courses: Array, registrations: Array, selectedCourseId: String }

  connect() {
    this._buildTermOptions()
    this._preselectFromCourse()
    this._updateCategories()
    this._updateCourses()
  }

  onTermChange() {
    this._updateCategories()
    this._updateCourses()
  }

  onCategoryChange() {
    this._updateCourses()
  }

  onCourseChange() {
    this._updateParticipants()
  }

  _preselectFromCourse() {
    if (!this.selectedCourseIdValue) return
    const course = this.coursesValue.find(c => String(c.id) === this.selectedCourseIdValue)
    if (!course) return
    this.termSelectTarget.value = course.termId ?? ""
  }

  _buildTermOptions() {
    const terms = new Map()
    this.coursesValue.forEach(c => {
      const key = c.termId ?? ""
      if (!terms.has(key)) terms.set(key, { id: key, name: c.termName || "Ohne Zeitraum", start: c.termStart || "" })
    })
    const sorted = [...terms.values()].sort((a, b) => b.start.localeCompare(a.start))

    this.termSelectTarget.innerHTML =
      '<option value="">Alle Zeiträume</option>' +
      sorted.map(t => `<option value="${this._esc(t.id)}">${this._esc(t.name)}</option>`).join("")
  }

  _updateCategories() {
    const termId = this.termSelectTarget.value
    const filtered = this.coursesValue.filter(c => termId === "" || String(c.termId ?? "") === termId)
    const categories = [...new Set(filtered.map(c => c.category).filter(Boolean))].sort()

    const current = this.categorySelectTarget.value
    this.categorySelectTarget.innerHTML =
      '<option value="">Alle Kategorien</option>' +
      categories.map(cat => `<option value="${this._esc(cat)}">${this._esc(cat)}</option>`).join("")
    if (categories.includes(current)) this.categorySelectTarget.value = current
  }

  _updateCourses() {
    const termId = this.termSelectTarget.value
    const category = this.categorySelectTarget.value
    const filtered = this.coursesValue
      .filter(c => termId === "" || String(c.termId ?? "") === termId)
      .filter(c => category === "" || c.category === category)
      .sort((a, b) => a.title.localeCompare(b.title))

    const current = this.courseSelectTarget.value
    this.courseSelectTarget.innerHTML =
      '<option value="">Kurs wählen...</option>' +
      filtered.map(c => `<option value="${c.id}">${this._esc(c.title)}</option>`).join("")
    if (filtered.some(c => String(c.id) === current)) this.courseSelectTarget.value = current

    this._updateParticipants()
  }

  _updateParticipants() {
    const courseId = this.courseSelectTarget.value
    if (!this.hasParticipantsListTarget) return

    if (!courseId) {
      this.participantsListTarget.innerHTML =
        '<li class="px-4 py-3 text-sm text-gray-400">Zuerst einen Kurs auswählen.</li>'
      return
    }

    const matches = this.registrationsValue
      .filter(r => String(r.courseId) === courseId)
      .sort((a, b) => a.name.localeCompare(b.name))

    if (matches.length === 0) {
      this.participantsListTarget.innerHTML =
        '<li class="px-4 py-3 text-sm text-gray-400">Keine Teilnehmenden in diesem Kurs.</li>'
      return
    }

    this.participantsListTarget.innerHTML = matches.map(r => `
      <li class="px-4 py-2.5 flex items-center gap-3 hover:bg-gray-50">
        <input type="checkbox" name="participant_ids[]" value="${r.participantId}" id="participant_${r.participantId}"
               class="h-4 w-4 rounded border-gray-300 text-primary-600 focus:ring-primary-500">
        <label for="participant_${r.participantId}" class="flex-1 text-sm cursor-pointer">
          <span class="font-semibold text-gray-900">${this._esc(r.name)}</span>
          <span class="text-gray-400 ml-1">${this._esc(r.email || "")}</span>
        </label>
        <span class="text-xs font-medium ${r.paidAmount ? "text-green-700" : "text-gray-400"} shrink-0">
          ${r.paidAmount ? this._esc(r.paidAmount) + " bezahlt" : "nicht bezahlt"}
        </span>
      </li>
    `).join("")
  }

  _esc(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
