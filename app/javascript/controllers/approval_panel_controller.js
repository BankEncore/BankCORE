import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "reason",
    "supervisorEmail", "supervisorPassword",
    "supervisorTellerNumber", "supervisorPin",
    "emailTab", "tellerTab", "emailPanel", "tellerPanel",
    "approvalReasonInput", "policyTriggerInput", "policyContextInput"
  ]

  static values = {
    approvalUrl: String,
    credentialMode: { type: String, default: "teller" }
  }

  connect() {
    this.applyMode()
  }

  show(event) {
    const policyTrigger = event.detail?.policyTrigger || ""
    const policyContext = event.detail?.policyContext || {}
    this.lastFocusedElement = document.activeElement

    this.credentialModeValue = "teller"
    this.applyMode()
    this.clearCredentials()

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

    this.focusActivePanel()
  }

  switchToTeller() {
    this.credentialModeValue = "teller"
    this.applyMode()
    this.focusActivePanel()
  }

  switchToEmail() {
    this.credentialModeValue = "email"
    this.applyMode()
    this.focusActivePanel()
  }

  applyMode() {
    const isTeller = this.credentialModeValue === "teller"
    if (this.hasTellerTabTarget) this.tellerTabTarget.classList.toggle("tab-active", isTeller)
    if (this.hasEmailTabTarget) this.emailTabTarget.classList.toggle("tab-active", !isTeller)
    if (this.hasTellerPanelTarget) this.tellerPanelTarget.classList.toggle("hidden", !isTeller)
    if (this.hasEmailPanelTarget) this.emailPanelTarget.classList.toggle("hidden", isTeller)
  }

  focusActivePanel() {
    if (this.credentialModeValue === "teller" && this.hasSupervisorTellerNumberTarget) {
      this.supervisorTellerNumberTarget.focus()
    } else if (this.credentialModeValue === "email" && this.hasSupervisorEmailTarget) {
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

    const fallbackPostButton = this.element.querySelector('#posting-form-header-submit')
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

  async request(event) {
    if (event?.preventDefault) event.preventDefault()
    const requestIdElement = this.element.querySelector('input[name="request_id"]')
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

    if (this.credentialModeValue === "teller") {
      formData.set("supervisor_teller_number", this.hasSupervisorTellerNumberTarget ? this.supervisorTellerNumberTarget.value : "")
      formData.set("supervisor_pin", this.hasSupervisorPinTarget ? this.supervisorPinTarget.value : "")
    } else {
      formData.set("supervisor_email_address", this.hasSupervisorEmailTarget ? this.supervisorEmailTarget.value : "")
      formData.set("supervisor_password", this.hasSupervisorPasswordTarget ? this.supervisorPasswordTarget.value : "")
    }

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
    if (this.hasSupervisorEmailTarget) this.supervisorEmailTarget.value = ""
    if (this.hasSupervisorPasswordTarget) this.supervisorPasswordTarget.value = ""
    if (this.hasSupervisorTellerNumberTarget) this.supervisorTellerNumberTarget.value = ""
    if (this.hasSupervisorPinTarget) this.supervisorPinTarget.value = ""
  }
}
