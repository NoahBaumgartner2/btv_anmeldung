import { Controller } from "@hotwired/stimulus"

// Setzt die iframe-src fürs Mail-Vorschau-Modal, bevor der modal-Controller es öffnet
// (data-action="click->notification-preview#setSrc click->modal#open" auf demselben Button).
export default class extends Controller {
  static targets = ["frame", "title"]

  setSrc(event) {
    const btn = event.currentTarget
    this.frameTarget.src = btn.dataset.previewUrl
    if (this.hasTitleTarget) this.titleTarget.textContent = btn.dataset.previewTitle || ""
  }
}
