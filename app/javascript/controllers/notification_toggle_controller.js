import { Controller } from "@hotwired/stimulus"

// Ein-/Ausschalten eines Benachrichtigungstyps in der Benachrichtigungszentrale
// (Admin::NotificationsController#toggle). Analog zu mail_toggle_controller,
// aber mit eigenem { enabled: "0"/"1" }-Payload statt mail_setting[field].
export default class extends Controller {
  static targets = ["label"]

  async toggle(event) {
    const button = event.currentTarget
    const url = button.dataset.url
    const newValue = button.dataset.value
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({ enabled: newValue })
      })

      if (!response.ok) return

      const nowEnabled = newValue === "1"
      const knob = button.querySelector("span")

      button.classList.toggle("bg-green-500", nowEnabled)
      button.classList.toggle("bg-gray-200", !nowEnabled)

      knob.classList.toggle("translate-x-6", nowEnabled)
      knob.classList.toggle("translate-x-1", !nowEnabled)

      button.dataset.value = nowEnabled ? "0" : "1"

      if (this.hasLabelTarget) {
        this.labelTarget.textContent = nowEnabled
          ? button.dataset.enabledText
          : button.dataset.disabledText
        this.labelTarget.classList.toggle("text-green-600", nowEnabled)
        this.labelTarget.classList.toggle("text-gray-400", !nowEnabled)
      }
    } catch (error) {
      console.error("[notification-toggle] fetch error:", error)
    }
  }
}
