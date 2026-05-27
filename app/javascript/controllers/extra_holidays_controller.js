import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.index = 0
  }

  addHoliday() {
    const i = this.index++
    const row = document.createElement("div")
    row.className = "flex flex-col gap-2 bg-gray-50 border border-gray-200 rounded-lg px-3 py-3"
    row.dataset.extraHolidaysTarget = "row"
    row.innerHTML =
      '<input type="text" name="extra_holidays[' + i + '][title]" placeholder="Bezeichnung (z.B. Sportferien)" ' +
        'class="w-full rounded-lg border border-gray-300 px-2.5 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 min-h-11">' +
      '<div class="flex items-center gap-2">' +
        '<input type="date" name="extra_holidays[' + i + '][start_date]" ' +
          'class="flex-1 min-w-0 rounded-lg border border-gray-300 px-2.5 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 min-h-11">' +
        '<span class="text-gray-400 text-sm shrink-0">–</span>' +
        '<input type="date" name="extra_holidays[' + i + '][end_date]" ' +
          'class="flex-1 min-w-0 rounded-lg border border-gray-300 px-2.5 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 min-h-11">' +
        '<button type="button" data-action="extra-holidays#removeHoliday" class="shrink-0 text-gray-400 hover:text-red-500 transition p-1 min-h-11 flex items-center" title="Entfernen">' +
          '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>' +
        '</button>' +
      '</div>'
    this.listTarget.appendChild(row)
  }

  removeHoliday(event) {
    event.currentTarget.closest("[data-extra-holidays-target='row']")?.remove()
  }
}
