import { Controller } from "@hotwired/stimulus"

// Kaskadierende Kursauswahl: Zeitraum (Term) -> Kategorie -> Kurs.
// Bekommt die vollständige Kursliste als JSON-Value (id, title, category,
// termId, termName, termStart) und filtert client-seitig - kein Server-
// Roundtrip nötig, da die Liste pro Verein überschaubar bleibt.
export default class extends Controller {
  static targets = ["termSelect", "categorySelect", "courseSelect"]
  static values = { courses: Array, selectedCourseId: String }

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
  }

  _esc(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
