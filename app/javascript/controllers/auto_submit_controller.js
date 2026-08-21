import { Controller } from "@hotwired/stimulus"

// Submits the enclosing form as soon as its input changes (e.g. a file
// picker). Kept as a Stimulus controller rather than an inline onchange=""
// handler because the app's CSP (script_src :self) blocks inline event
// handler attributes.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
