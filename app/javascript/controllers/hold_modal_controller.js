import { Controller } from "@hotwired/stimulus"

function addBusinessDays(date, days) {
  const d = new Date(date)
  let count = 0
  while (count < days) {
    d.setDate(d.getDate() + 1)
    if (d.getDay() !== 0 && d.getDay() !== 6) count++
  }
  return d.toISOString().slice(0, 10)
}

export default class extends Controller {
  static targets = ["modal", "reasonSelect", "untilInput"]

  openFromButton(event) {
    const button = event.currentTarget
    const row = button.closest("[data-check-row]")
    if (!row) return

    this.currentRow = row
    const holdReason = row.querySelector('[data-check-field="holdReason"]')?.value || ""
    const holdUntil = row.querySelector('[data-check-field="holdUntil"]')?.value || ""

    this.reasonSelectTarget.value = holdReason
    this.untilInputTarget.value = holdUntil || (holdReason ? addBusinessDays(new Date(), 5) : "")

    this.modalTarget.showModal()
  }

  onReasonChange() {
    const reason = this.reasonSelectTarget.value
    if (reason) {
      this.untilInputTarget.value = addBusinessDays(new Date(), 5)
    } else {
      this.untilInputTarget.value = ""
    }
  }

  apply() {
    if (!this.currentRow) return

    const reason = this.reasonSelectTarget.value?.trim() || ""
    const until = reason ? this.untilInputTarget.value : ""

    const reasonInput = this.currentRow.querySelector('[data-check-field="holdReason"]')
    const untilInput = this.currentRow.querySelector('[data-check-field="holdUntil"]')
    const button = this.currentRow.querySelector(".hold-button")

    if (reasonInput) reasonInput.value = reason
    if (untilInput) untilInput.value = until

    if (button) {
      button.classList.remove("btn-ghost")
      button.classList.add("btn-warning")
    }

    this.close()
    this.emitChanged()
  }

  clear() {
    if (!this.currentRow) return

    const reasonInput = this.currentRow.querySelector('[data-check-field="holdReason"]')
    const untilInput = this.currentRow.querySelector('[data-check-field="holdUntil"]')
    const button = this.currentRow.querySelector(".hold-button")

    if (reasonInput) reasonInput.value = ""
    if (untilInput) untilInput.value = ""

    if (button) {
      button.classList.remove("btn-warning")
      button.classList.add("btn-ghost")
    }

    this.reasonSelectTarget.value = ""
    this.untilInputTarget.value = ""

    this.close()
    this.emitChanged()
  }

  handleClose() {
    this.currentRow = null
  }

  close() {
    this.modalTarget.close()
    this.currentRow = null
  }

  emitChanged() {
    this.element.dispatchEvent(new CustomEvent("tx:changed", { bubbles: true }))
  }
}
