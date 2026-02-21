import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "reason", "supervisorEmail", "supervisorPassword", "approvalReasonInput", "policyTriggerInput", "policyContextInput"]

  static values = {
    approvalUrl: String
  }

  show(event) {
    const policyTrigger = event.detail?.policyTrigger || ""
    const policyContext = event.detail?.policyContext || {}

    if (this.hasPanelTarget) {
      this.panelTarget.hidden = false
    }

    if (this.hasReasonTarget) {
      this.reasonTarget.textContent = event.detail?.reason || "Approval required"
    }

    if (this.hasPolicyTriggerInputTarget) {
      this.policyTriggerInputTarget.value = policyTrigger
    }

    if (this.hasPolicyContextInputTarget) {
      this.policyContextInputTarget.value = JSON.stringify(policyContext)
    }
  }

  hide() {
    if (this.hasPanelTarget) {
      this.panelTarget.hidden = true
    }
  }

  async request() {
    const requestIdElement = this.element.querySelector('[data-posting-form-target="requestId"]')
    if (!requestIdElement || !requestIdElement.value) {
      this.element.dispatchEvent(new CustomEvent("tx:approval-error", {
        bubbles: true,
        detail: { message: "Approval failed: missing request ID" }
      }))
      return
    }

    const formData = new FormData()
    formData.set("request_id", requestIdElement.value)
    formData.set("reason", this.hasApprovalReasonInputTarget ? this.approvalReasonInputTarget.value : "")
    formData.set("policy_trigger", this.hasPolicyTriggerInputTarget ? this.policyTriggerInputTarget.value : "")
    formData.set("policy_context", this.hasPolicyContextInputTarget ? this.policyContextInputTarget.value : "{}")
    formData.set("supervisor_email_address", this.hasSupervisorEmailTarget ? this.supervisorEmailTarget.value : "")
    formData.set("supervisor_password", this.hasSupervisorPasswordTarget ? this.supervisorPasswordTarget.value : "")

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    try {
      const response = await fetch(this.approvalUrlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: formData
      })

      const body = await response.json()
      if (!response.ok || !body.ok) {
        this.element.dispatchEvent(new CustomEvent("tx:approval-error", {
          bubbles: true,
          detail: { message: body.error || "Approval failed" }
        }))
        return
      }

      this.hide()
      this.element.dispatchEvent(new CustomEvent("tx:approval-granted", {
        bubbles: true,
        detail: { approvalToken: body.approval_token }
      }))
    } catch (_error) {
      this.element.dispatchEvent(new CustomEvent("tx:approval-error", {
        bubbles: true,
        detail: { message: "Approval failed" }
      }))
    }
  }
}
