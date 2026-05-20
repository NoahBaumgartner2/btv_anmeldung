import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["participantSelect", "trialBanner", "trialField", "trialBtn", "submitBtn"]
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
    this.trialFieldTarget.value = "true"
    this.trialFieldTarget.closest("form").requestSubmit()
  }

  #showTrial() {
    this.trialBannerTarget.classList.remove("hidden")
    this.trialBtnTarget.classList.remove("hidden")
    this.trialBtnTarget.classList.add("inline-flex")
  }

  #hideTrial() {
    this.trialBannerTarget.classList.add("hidden")
    this.trialBtnTarget.classList.add("hidden")
    this.trialBtnTarget.classList.remove("inline-flex")
    this.trialFieldTarget.value = "false"
  }
}
