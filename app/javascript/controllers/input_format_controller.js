import { Controller } from "@hotwired/stimulus"

// Formatiert Telefonnummer/AHV-Nummer/IBAN-Felder live beim Tippen ins
// einheitliche Anzeigeformat, ohne auf ein Server-Roundtrip zu warten.
// Die serverseitige Normalisierung (siehe PhoneNumberFormatter etc.) bleibt
// die Quelle der Wahrheit für gespeicherte Werte; das hier ist nur UX-Zucker.
const FORMATTERS = {
  phone(raw) {
    const digits = raw.replace(/[^\d+]/g, "")
    if (!digits) return raw

    let national
    if (digits.startsWith("+41")) national = digits.slice(3)
    else if (digits.startsWith("0041")) national = digits.slice(4)
    else if (digits.startsWith("0")) national = digits.slice(1)
    else return raw

    if (national.length !== 9) return raw
    return `+41 ${national.slice(0, 2)} ${national.slice(2, 5)} ${national.slice(5, 7)} ${national.slice(7, 9)}`
  },

  ahv(raw) {
    const digits = raw.replace(/\D/g, "").slice(0, 13)
    if (!digits) return raw
    return [digits.slice(0, 3), digits.slice(3, 7), digits.slice(7, 11), digits.slice(11, 13)]
      .filter((part) => part.length > 0)
      .join(".")
  },

  iban(raw) {
    const chars = raw.replace(/\s/g, "").toUpperCase()
    if (!chars) return raw
    return chars.match(/.{1,4}/g).join(" ")
  },

  capitalize(raw) {
    if (!raw) return raw
    return raw
      .split(/([\s-])/)
      .map((part) => (/^\p{L}/u.test(part) ? part[0].toUpperCase() + part.slice(1) : part))
      .join("")
  },
}

export default class extends Controller {
  static values = { type: String }

  format() {
    const formatter = FORMATTERS[this.typeValue]
    if (!formatter) return

    const significantCountBeforeCursor = this.countSignificant(
      this.element.value.slice(0, this.element.selectionStart)
    )

    const formatted = formatter(this.element.value)
    if (formatted === this.element.value) return

    this.element.value = formatted
    const newPos = this.positionForCount(formatted, significantCountBeforeCursor)
    this.element.setSelectionRange(newPos, newPos)
  }

  // Zählt "bedeutungstragende" Zeichen (Ziffern, bei Telefon auch "+", bei
  // IBAN auch Buchstaben) — Trennzeichen wie Leerzeichen/Punkte zählen nicht,
  // damit die Cursorposition nach dem Reformatieren stabil bleibt.
  countSignificant(str) {
    return (str.match(/[\d+\p{L}]/gu) || []).length
  }

  positionForCount(str, count) {
    if (count <= 0) return 0
    let seen = 0
    for (let i = 0; i < str.length; i++) {
      if (/[\d+\p{L}]/u.test(str[i])) seen++
      if (seen === count) return i + 1
    }
    return str.length
  }
}
