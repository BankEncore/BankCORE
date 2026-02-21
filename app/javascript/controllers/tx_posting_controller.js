import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async handlePostRequested(event) {
    const url = event.detail?.url
    const formData = event.detail?.formData
    const requestId = event.detail?.requestId

    if (!url || !formData) {
      this.emitPostFailed("Posting request is incomplete", requestId)
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
        this.emitPostFailed(body.error || "Posting failed.", requestId)
        return
      }

      this.element.dispatchEvent(new CustomEvent("tx:posted-success", {
        bubbles: true,
        detail: {
          postingBatchId: body.posting_batch_id,
          tellerTransactionId: body.teller_transaction_id,
          requestId,
          postedAt: new Date().toISOString()
        }
      }))
    } catch (error) {
      this.emitPostFailed(error.message || "Posting failed.", requestId)
    }
  }

  emitPostFailed(error, requestId) {
    this.element.dispatchEvent(new CustomEvent("tx:posted-failed", {
      bubbles: true,
      detail: {
        error,
        requestId
      }
    }))
  }
}
