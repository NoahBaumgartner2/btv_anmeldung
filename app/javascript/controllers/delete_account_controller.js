import { Controller } from "@hotwired/stimulus"

// Steuert das 3-stufige Lösch-Modal auf accounts/show.html.erb:
// Schritt 1 – Umfrage (Grund auswählen)
// Schritt 2 – Hinweis "Was geht verloren"
// Schritt 3 – Passwort-Bestätigung
export default class extends Controller {
  static targets = [
    "modal",
    "content",
    "step",
    "stepDot",
    "stepLabel",
    "reasonRadio",
    "otherWrapper",
    "reasonText",
    "nextButton",
    "hiddenReason",
    "hiddenReasonText"
  ]

  connect() {
    this.reset()
  }

  open() {
    this.reset()
    this.modalTarget.classList.remove("hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.reset()
  }

  // Schliesst das Modal nur, wenn auf den Backdrop (modalTarget selbst) geklickt wurde,
  // nicht wenn auf den Inhalt geklickt wurde.
  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  next() {
    const current = this.currentStep()
    if (current < 3) this.goTo(current + 1)
  }

  reasonChanged(event) {
    this.nextButtonTarget.disabled = false
    this.otherWrapperTarget.classList.toggle("hidden", event.target.value !== "other")
  }

  reset() {
    this.reasonRadioTargets.forEach(radio => { radio.checked = false })
    this.reasonTextTarget.value = ""
    this.otherWrapperTarget.classList.add("hidden")
    this.nextButtonTarget.disabled = true
    this.goTo(1)
  }

  goTo(step) {
    this.stepTargets.forEach(el => {
      const stepNumber = parseInt(el.dataset.stepNumber, 10)
      el.classList.toggle("hidden", stepNumber !== step)
    })

    this.stepDotTargets.forEach(dot => {
      const dotNumber = parseInt(dot.dataset.stepNumber, 10)
      dot.classList.remove("w-2", "w-6", "bg-gray-200", "bg-red-500", "bg-red-300")
      if (dotNumber === step) {
        dot.classList.add("w-6", "bg-red-500")
      } else if (dotNumber < step) {
        dot.classList.add("w-2", "bg-red-300")
      } else {
        dot.classList.add("w-2", "bg-gray-200")
      }
    })

    this.stepLabelTarget.textContent = `Schritt ${step} von 3`

    if (step === 3) {
      const checked = this.reasonRadioTargets.find(r => r.checked)
      this.hiddenReasonTarget.value     = checked ? checked.value : ""
      this.hiddenReasonTextTarget.value = this.reasonTextTarget.value || ""
    }
  }

  currentStep() {
    const visible = this.stepTargets.find(el => !el.classList.contains("hidden"))
    return visible ? parseInt(visible.dataset.stepNumber, 10) : 1
  }
}
