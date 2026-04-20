import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

const German = {
  weekdays: {
    shorthand: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"],
    longhand: ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"],
  },
  months: {
    shorthand: ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"],
    longhand: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
  },
  firstDayOfWeek: 1,
  weekAbbreviation: "KW",
  rangeSeparator: " bis ",
  scrollTitle: "Zum Ändern scrollen",
  toggleTitle: "Zum Umschalten klicken",
  time_24hr: true,
}

export default class extends Controller {
  static values = {
    dateFormat: { type: String, default: "d.m.Y" },
    minDate: { type: String, default: "" },
    maxDate: { type: String, default: "" },
  }

  connect() {
    this.fp = flatpickr(this.element, {
      locale: German,
      dateFormat: "Y-m-d",
      altInput: true,
      altFormat: this.dateFormatValue,
      altInputClass: this.element.className,
      allowInput: true,
      minDate: this.minDateValue || null,
      maxDate: this.maxDateValue || null,
    })
  }

  disconnect() {
    if (this.fp) {
      this.fp.destroy()
      this.fp = null
    }
  }
}
