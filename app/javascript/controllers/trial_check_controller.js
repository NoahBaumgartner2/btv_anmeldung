import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["participantSelect", "trialBanner", "trialField", "trialBtn", "submitBtn", "trialSession", "trialSelect", "trialEmpty"]
  static values  = { courseId: Number, allowsTrial: Boolean }

  #abortController = null

  connect() {
    if (this.hasParticipantSelectTarget) {
      this.participantChanged()
    }
  }

  async participantChanged() {
    if (this.#abortController) {
      this.#abortController.abort()
    }

    const participantId = this.participantSelectTarget.value
    if (!this.allowsTrialValue || !participantId) {
      this.#hideTrial()
      return
    }

    this.#abortController = new AbortController()
    try {
      const res = await fetch(
        `/course_registrations/trial_eligible?course_id=${this.courseIdValue}&participant_id=${participantId}`,
        { headers: { "Accept": "application/json" }, signal: this.#abortController.signal }
      )
      const data = await res.json()
      data.eligible ? this.#showTrial() : this.#hideTrial()
    } catch (e) {
      if (e.name !== "AbortError") this.#hideTrial()
    }
  }

  submitTrial() {
    // Schnuppern nur möglich, wenn ein Training auswählbar ist.
    if (this.hasTrialSelectTarget && !this.trialSelectTarget.value) {
      this.trialSelectTarget.focus()
      return
    }
    this.trialFieldTarget.value = "true"
    this.trialFieldTarget.closest("form").requestSubmit()
  }

  #showTrial() {
    this.trialBannerTarget.classList.remove("hidden")

    if (this.hasTrialSessionTarget) {
      this.trialSessionTarget.classList.remove("hidden")
    }

    // Ohne wählbare Sessions kann nicht geschnuppert werden → Button deaktivieren.
    const noSessions = this.hasTrialEmptyTarget
    if (noSessions) {
      this.trialBtnTarget.classList.add("hidden")
      this.trialBtnTarget.classList.remove("inline-flex")
    } else {
      this.trialBtnTarget.classList.remove("hidden")
      this.trialBtnTarget.classList.add("inline-flex")
    }
  }

  #hideTrial() {
    this.trialBannerTarget.classList.add("hidden")
    this.trialBtnTarget.classList.add("hidden")
    this.trialBtnTarget.classList.remove("inline-flex")
    this.trialFieldTarget.value = "false"

    if (this.hasTrialSessionTarget) {
      this.trialSessionTarget.classList.add("hidden")
    }
  }
}
