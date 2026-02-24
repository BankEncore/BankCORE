import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkRows", "checkTemplate"]

  addCheckRow(event) {
    event.preventDefault()
    const template = this.checkTemplateTarget.content.cloneNode(true)
    const rows = this.checkRowsTarget.querySelectorAll("[data-check-row]")
    const nextIndex = rows.length + 1
    const indexCell = template.querySelector("[data-check-index]")
    if (indexCell) indexCell.textContent = String(nextIndex).padStart(2, "0")
    this.checkRowsTarget.appendChild(template)
    this.emitChanged()
  }

  removeCheckRow(event) {
    event.preventDefault()
    const row = event.target.closest("[data-check-row]")
    if (row) {
      row.remove()
      this.renumberRows()
    }
    this.emitChanged()
  }

  renumberRows() {
    this.checkRowsTarget.querySelectorAll("[data-check-row] [data-check-index]").forEach((cell, i) => {
      cell.textContent = String(i + 1).padStart(2, "0")
    })
  }

  emitChanged() {
    this.element.dispatchEvent(new CustomEvent("tx:changed", { bubbles: true }))
  }
}
