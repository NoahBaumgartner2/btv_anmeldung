import { Controller } from "@hotwired/stimulus"

// Generische Tab-Navigation. Buttons mit [data-tabs-target="tab"] und
// [data-tab-id] schalten Panels mit [data-tabs-target="panel"] und
// gleichem [data-tab-id] sichtbar/unsichtbar.
//
// Markup:
//   <div data-controller="tabs"
//        data-tabs-active-class="border-primary-600 text-primary-700"
//        data-tabs-inactive-class="border-transparent text-gray-500">
//     <button data-tabs-target="tab" data-tab-id="a" data-action="click->tabs#select" class="...">A</button>
//     <div data-tabs-target="panel" data-tab-id="a">Inhalt A</div>
//     <div data-tabs-target="panel" data-tab-id="b" class="hidden">Inhalt B</div>
//   </div>
export default class extends Controller {
  static targets = ["tab", "panel"]
  static classes = ["active", "inactive"]

  select(event) {
    this.show(event.currentTarget.dataset.tabId)
  }

  show(id) {
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabId === id
      tab.classList.remove(...this.activeClasses, ...this.inactiveClasses)
      tab.classList.add(...(active ? this.activeClasses : this.inactiveClasses))
    })
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tabId !== id)
    })
  }
}
