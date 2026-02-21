import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "reason", "supervisorEmail", "supervisorPassword", "approvalReasonInput", "policyTriggerInput", "policyContextInput"]

  static values = {
    approvalUrl: String
  }

  show(event) {
    const policyTrigger = event.detail?.policyTrigger || ""
    const policyContext = event.detail?.policyContext || {}
    this.lastFocusedElement = document.activeElement

    if (this.hasPanelTarget) {
      if (typeof this.panelTarget.showModal === "function") {
        this.panelTarget.showModal()
      } else {
        this.panelTarget.setAttribute("open", "open")
      }
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

    if (this.hasSupervisorEmailTarget) {
      this.supervisorEmailTarget.focus()
    }
  }

  hide() {
    if (this.hasPanelTarget) {
      if (typeof this.panelTarget.close === "function") {
        this.panelTarget.close()
      } else {
        this.panelTarget.removeAttribute("open")
      }
    }

    this.clearCredentials()

    if (this.lastFocusedElement && typeof this.lastFocusedElement.focus === "function") {
      this.lastFocusedElement.focus()
      return
    }

    const fallbackPostButton = this.element.querySelector('[data-posting-form-target="headerSubmitButton"]') || this.element.querySelector('[data-posting-form-target="submitButton"]')
    if (fallbackPostButton && typeof fallbackPostButton.focus === "function") {
      fallbackPostButton.focus()
    }
  }

  deny() {
    this.hide()
    this.element.dispatchEvent(new CustomEvent("tx:approval-cleared", { bubbles: true }))
  }

  handleDialogClosed() {
    this.clearCredentials()
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

  clearCredentials() {
    if (this.hasSupervisorEmailTarget) {
      this.supervisorEmailTarget.value = ""
    }

    if (this.hasSupervisorPasswordTarget) {
      this.supervisorPasswordTarget.value = ""
    }
  }
}
