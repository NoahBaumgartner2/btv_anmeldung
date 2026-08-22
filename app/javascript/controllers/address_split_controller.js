import { Controller } from "@hotwired/stimulus"

// Browser-Adress-Autofill kennt kein separates "Hausnummer"-Feld und kippt
// die komplette Adresse (z.B. "Musterstrasse 12a") ins Strassenfeld. Dieser
// Controller erkennt die angehängte Hausnummer und trennt sie automatisch
// ins Hausnummer-Feld ab, sobald sie ausgefüllt/eingefügt wird.
export default class extends Controller {
  static targets = ["street", "houseNumber"]

  split() {
    const match = this.streetTarget.value.match(/^(.+?),?\s+(\d+[a-zA-Z]?)$/)
    if (!match) return

    // Ein Treffer heisst: das Strassenfeld enthält Name+Nummer zusammen -
    // das passiert nur durch Autofill, das die ganze Adresse reinkippt (und
    // dabei oft auch gleich ein falsches/leeres Nr.-Feld setzt). Deshalb hier
    // bewusst immer überschreiben, statt ein evtl. falsches Nr.-Feld stehen
    // zu lassen.
    const [, street, houseNumber] = match
    this.streetTarget.value = street.trim()
    this.houseNumberTarget.value = houseNumber
  }
}
