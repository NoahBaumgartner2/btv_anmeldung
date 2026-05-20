import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["participantSelect", "trialBanner", "trialField", "trialBtn", "submitBtn"]
  static values  = { courseId: Number, allowsTrial: Boolean }

  connect() {
    if (this.hasParticipantSelectTarget) {
      this.participantChanged()
    }
  }

  async participantChanged() {
    const participantId = this.participantSelectTarget.value
    if (!this.allowsTrialValue || !participantId) {
      this.#hideTrial()
      return
    }

    try {
      const res = await fetch(
        `/course_registrations/trial_eligible?course_id=${this.courseIdValue}&participant_id=${participantId}`,
        { headers: { "Accept": "application/json" } }
      )
      const data = await res.json()
      data.eligible ? this.#showTrial() : this.#hideTrial()
    } catch {
      this.#hideTrial()
    }
  }

  submitTrial() {
    this.trialFieldTarget.value = "true"
    this.element.closest("form").requestSubmit()
  }

  #showTrial() {
    this.trialBannerTarget.classList.remove("hidden")
    this.trialBtnTarget.classList.remove("hidden")
  }

  #hideTrial() {
    this.trialBannerTarget.classList.add("hidden")
    this.trialBtnTarget.classList.add("hidden")
    this.trialFieldTarget.value = "false"
  }
}
