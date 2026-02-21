import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async handleValidateRequested(event) {
    const url = event.detail?.url
    const formData = event.detail?.formData

    if (!url || !formData) {
      this.emitValidationFailed(["Validation request is incomplete"], event.detail?.requestId)
      return
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: formData
      })

      const body = await response.json()
      if (!response.ok || !body.ok) {
        this.emitValidationFailed(body.errors || [body.error || "Validation failed"], event.detail?.requestId)
        return
      }

      this.element.dispatchEvent(new CustomEvent("tx:validated", {
        bubbles: true,
        detail: body
      }))
    } catch (_error) {
      this.emitValidationFailed(["Validation failed"], event.detail?.requestId)
    }
  }

  emitValidationFailed(errors, requestId) {
    this.element.dispatchEvent(new CustomEvent("tx:validation-failed", {
      bubbles: true,
      detail: {
        errors,
        requestId
      }
    }))
  }
}
