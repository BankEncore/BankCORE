import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "requestId", "approvalToken", "reasonCode", "memo", "errorMessage"]

  submitReversal() {
    this.hideError()
    if (!this.hasReasonCodeTarget || !this.reasonCodeTarget.value) {
      this.showError("Reason code is required")
      return
    }
    if (!this.hasMemoTarget || !this.memoTarget.value.trim()) {
      this.showError("Memo is required")
      return
    }

    const policyContext = {
      original_teller_transaction_id: this.element.dataset.originalTransactionId || "",
      original_ref: this.element.dataset.originalRef || "",
      original_amount: this.element.dataset.originalAmount || "",
      original_type: this.element.dataset.originalType || ""
    }

    this.element.dispatchEvent(new CustomEvent("tx:approval-required", {
      bubbles: true,
      detail: {
        policyTrigger: "transaction_reversal",
        policyContext,
        reason: "Reversal requires supervisor approval"
      }
    }))
  }

  handleApprovalGranted(event) {
    const token = event.detail?.approvalToken
    if (token && this.hasApprovalTokenTarget) {
      this.approvalTokenTarget.value = token
    }
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  handleApprovalError(event) {
    const message = event.detail?.message || "Approval failed"
    this.showError(message)
  }

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove("hidden")
    }
  }

  hideError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = ""
      this.errorMessageTarget.classList.add("hidden")
    }
  }

  dispatch(name, options = {}) {
    this.element.dispatchEvent(new CustomEvent(name, { bubbles: true, ...options }))
  }
}
