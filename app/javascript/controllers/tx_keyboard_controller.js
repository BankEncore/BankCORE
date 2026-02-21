import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleKeydown(event) {
    if (!this.focusInsideWorkspace()) {
      return
    }

    if (event.ctrlKey && event.key === "Enter") {
      event.preventDefault()
      this.element.dispatchEvent(new CustomEvent("tx:submit-requested", { bubbles: true }))
      const form = this.element.querySelector("#posting-form")
      if (form) {
        form.requestSubmit()
      }
      return
    }

    if (event.key !== "Escape") {
      return
    }

    const approvalPanel = this.element.querySelector('[data-approval-panel-target="panel"]')
    const approvalOpen = approvalPanel && (approvalPanel.open || !approvalPanel.hidden)
    if (approvalOpen) {
      event.preventDefault()
      this.element.dispatchEvent(new CustomEvent("tx:approval-cleared", { bubbles: true }))
      return
    }

    const cancelButton = this.element.querySelector('[data-action*="posting-form#resetForm"]')
    if (cancelButton) {
      event.preventDefault()
      this.element.dispatchEvent(new CustomEvent("tx:cancel-requested", { bubbles: true }))
      cancelButton.click()
    }
  }

  focusInsideWorkspace() {
    const active = document.activeElement
    if (!active) {
      return false
    }

    return this.element.contains(active)
  }
}
