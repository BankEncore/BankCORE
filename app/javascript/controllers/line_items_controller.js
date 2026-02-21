import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkRows", "checkTemplate"]

  addCheckRow(event) {
    event.preventDefault()
    const template = this.checkTemplateTarget.content.cloneNode(true)
    this.checkRowsTarget.appendChild(template)
    this.emitChanged()
  }

  removeCheckRow(event) {
    event.preventDefault()
    const row = event.target.closest("[data-check-row]")
    if (row) {
      row.remove()
    }
    this.emitChanged()
  }

  emitChanged() {
    this.element.dispatchEvent(new CustomEvent("tx:changed", { bubbles: true }))
  }
}
