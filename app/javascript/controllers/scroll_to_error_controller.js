import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const errorBlock = this.element.querySelector('[data-error-scroll-target]')
    if (errorBlock) {
      errorBlock.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }
}
