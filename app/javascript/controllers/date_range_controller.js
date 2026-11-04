import { Controller } from "@hotwired/stimulus"

// Zeitraum-Auswahl mit einem Kalender für Von und Bis. Die Werte liegen in den versteckten
// Feldern from/to, damit das Formular wie mit zwei normalen Datumsfeldern funktioniert.
export default class extends Controller {
  static targets = ["input", "from", "to", "fromLabel", "toLabel", "fromSegment", "toSegment"]
  static values = {
    months: Array, monthsShort: Array, weekdays: Array, weekdaysShort: Array,
    placeholder: String, clear: String, close: String,
  }

  connect() {
    this.fp = window.flatpickr(this.inputTarget, {
      mode: "range",
      dateFormat: "Y-m-d",
      defaultDate: [ this.fromTarget.value, this.toTarget.value ].filter(Boolean),
      showMonths: window.innerWidth >= 768 ? 2 : 1,
      monthSelectorType: "static",
      positionElement: this.element,
      clickOpens: false,
      disableMobile: true,
      locale: {
        firstDayOfWeek: 1,
        weekdays: { shorthand: this.weekdaysShortValue, longhand: this.weekdaysValue },
        months: { shorthand: this.monthsShortValue, longhand: this.monthsValue },
      },
      onReady: (_dates, _str, instance) => this.decorate(instance),
      onChange: (dates) => this.sync(dates),
      onOpen: () => this.markActive(this.fp.selectedDates.length),
      onClose: () => this.markActive(null),
    })
  }

  disconnect() {
    this.fp?.destroy()
    this.fp = null
  }

  open(event) {
    event.preventDefault()
    this.fp.open()
  }

  close() {
    this.fp.close()
  }

  decorate(instance) {
    instance.calendarContainer.classList.add("fp-airbnb")
    const footer = document.createElement("div")
    footer.className = "fp-airbnb-footer"
    footer.append(
      this.footerButton(this.clearValue, "fp-airbnb-clear", () => instance.clear()),
      this.footerButton(this.closeValue, "fp-airbnb-close", () => instance.close()),
    )
    instance.calendarContainer.append(footer)
  }

  footerButton(text, className, onClick) {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = text
    button.className = className
    button.addEventListener("click", onClick)
    return button
  }

  sync(dates) {
    this.write(this.fromTarget, this.fromLabelTarget, dates[0])
    this.write(this.toTarget, this.toLabelTarget, dates[1])
    if (this.fp?.isOpen) this.markActive(dates.length)
  }

  write(field, label, date) {
    field.value = date ? this.fp.formatDate(date, "Y-m-d") : ""
    label.textContent = date ? this.fp.formatDate(date, "d.m.Y") : this.placeholderValue
    label.classList.toggle("text-gray-500", !date)
  }

  // Zeigt, welches Datum als Nächstes gewählt wird: erst Von, dann Bis.
  markActive(selectedCount) {
    this.fromSegmentTarget.toggleAttribute("data-active", selectedCount === 0 || selectedCount === 2)
    this.toSegmentTarget.toggleAttribute("data-active", selectedCount === 1)
  }
}
