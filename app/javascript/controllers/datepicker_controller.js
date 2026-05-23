import { Controller } from "@hotwired/stimulus"

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
    this.fp = window.flatpickr(this.element, {
      locale: German,
      dateFormat: "Y-m-d",
      altInput: true,
      altFormat: this.dateFormatValue,
      altInputClass: this.element.className,
      allowInput: true,
      minDate: this.minDateValue || null,
      maxDate: this.maxDateValue || null,
      onOpen: [(_dates, _str, instance) => {
        const cal = instance.calendarContainer
        const vw = window.innerWidth
        const vh = window.innerHeight
        const MARGIN = 6

        if (vw < 400) {
          // Fixed + horizontal centering on very narrow screens
          cal.style.position = "fixed"
          cal.style.left = "50%"
          cal.style.transform = "translateX(-50%)"

          const inputEl = instance.altInput || instance.input
          const inputRect = inputEl.getBoundingClientRect()
          const calH = cal.offsetHeight || 280

          if (inputRect.bottom + calH + MARGIN <= vh) {
            cal.style.top = (inputRect.bottom + MARGIN) + "px"
          } else if (inputRect.top - calH - MARGIN > 0) {
            cal.style.top = (inputRect.top - calH - MARGIN) + "px"
          } else {
            cal.style.top = Math.max(MARGIN, (vh - calH) / 2) + "px"
          }
          return
        }

        // Horizontal: fix right overflow, then clamp against left edge
        const rect = cal.getBoundingClientRect()
        const currentLeft = parseFloat(cal.style.left) || 0
        let newLeft = currentLeft - Math.max(0, rect.right - vw + MARGIN)
        newLeft = Math.max(MARGIN, newLeft)
        cal.style.left = newLeft + "px"

        // Vertical: reposition above input when calendar would go below viewport
        const updated = cal.getBoundingClientRect()
        if (updated.bottom > vh - MARGIN) {
          const inputEl = instance.altInput || instance.input
          const inputRect = inputEl.getBoundingClientRect()
          const topAbove = inputRect.top - updated.height - MARGIN
          if (topAbove > 0) cal.style.top = topAbove + "px"
        }
      }],
    })
  }

  disconnect() {
    if (this.fp) {
      this.fp.destroy()
      this.fp = null
    }
  }
}
