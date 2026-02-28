/**
 * Base controller for workflow-specific posting forms.
 * Not registered with Stimulus; extended by deposit-form, withdrawal-form, etc.
 */
import { Controller } from "@hotwired/stimulus"
import {
  getSections,
  getEntryProfile,
  getAmountInputMode,
  getEffectiveAmountSource,
  getCashImpactProfile,
  getRequiresPrimaryAccount,
  getRequiresCounterpartyAccount,
  getRequiresCashAccount,
  getRequiresSettlementAccount,
  hasSection as workflowHasSectionInConfig
} from "services/posting_workflows"
import { appendEntriesAndTypePayload } from "services/posting_payload"

export default class extends Controller {
  static targets = [
    "transactionType",
    "requestId",
    "approvalToken",
    "submitButton",
    "headerSubmitButton",
    "receiptPanel",
    "receiptBatchId",
    "receiptTransactionId",
    "receiptRequestId",
    "receiptPostedAt",
    "receiptLink",
    "receiptNewButton",
    "postSuccessModal",
    "postSuccessReceiptLink",
    "postSuccessIds",
    "postSuccessNewButton",
    "headerStateBadge",
    "headerStatus",
    "message",
    "postingPreviewSection",
    "postingPreviewBody",
    "postingPreviewEmpty",
    "statusBadge",
    "availabilitySection",
    "availabilityBody",
    "availabilityEmpty"
  ]

  static values = {
    openingCashCents: Number,
    defaultTransactionType: String,
    validateUrl: String,
    accountReferenceUrl: String,
    accountHistoryUrl: String,
    advisoriesUrl: String,
    workflowSchemaUrl: String,
    receiptUrlTemplate: String,
    drawerReference: String
  }

  connect() {
    this.postedLocked = false
    this.workflowSchema = null
    this.defaultCashAccountReference = ""
    if (this.hasDefaultTransactionTypeValue && this.defaultTransactionTypeValue) {
      this.transactionTypeTarget.value = this.defaultTransactionTypeValue
    }
    this.loadWorkflowSchema()
    this.ensureRequestId()
    this.resetReceipt()
    this.clearMessage()
    this.recalculate()
  }

  async loadWorkflowSchema() {
    if (!this.hasWorkflowSchemaUrlValue || !this.workflowSchemaUrlValue) {
      return
    }

    try {
      const response = await fetch(this.workflowSchemaUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) return

      const payload = await response.json()
      this.workflowSchema = payload.workflows || {}
      this.recalculate()
    } catch {
    }
  }

  recalculate() {
    throw new Error("recalculate() must be implemented by workflow controller")
  }

  getState() {
    throw new Error("getState() must be implemented by workflow controller")
  }

  effectiveAmountCents() {
    throw new Error("effectiveAmountCents() must be implemented by workflow controller")
  }

  resetFormFieldClearing(_isAfterPost = false) {
  }

  focusFirstField() {
  }

  submitFromHeader(event) {
    event.preventDefault()
    const form = this.element.querySelector("#posting-form")
    if (form) {
      this.submit({ target: form, preventDefault: () => {} })
    }
  }

  async submit(event) {
    if (event && typeof event.preventDefault === "function") {
      event.preventDefault()
    }

    if (this.postedLocked) {
      this.renderMessage("Transaction already posted. Select New Transaction to continue.", "warning")
      return
    }

    this.resetReceipt()
    this.recalculate()

    if (this.submitButtonTarget.disabled) {
      this.renderMessage("Posting blocked. Resolve missing fields and balance delta first.", "error")
      return
    }

    this.ensureRequestId()
    this.setHeaderState("Validating")
    const validation = await this.requestValidation()
    if (!validation.ok) {
      this.setHeaderState("Editing")
      this.renderMessage(validation.errors.join("; "), "error")
      return
    }

    if (validation.approval_required && !this.approvalTokenTarget.value) {
      this.element.dispatchEvent(new CustomEvent("tx:approval-required", {
        bubbles: true,
        detail: {
          reason: validation.approval_reason || "Approval required",
          policyTrigger: validation.approval_policy_trigger || "",
          policyContext: validation.approval_policy_context || {}
        }
      }))
      this.setHeaderState("Approval Required")
      this.renderMessage("Supervisor approval is required before posting.", "warning")
      this.submitButtonTarget.disabled = true
      if (this.hasHeaderSubmitButtonTarget) {
        this.headerSubmitButtonTarget.disabled = true
      }
      return
    }

    const submittedRequestId = this.generateRequestId()
    const ridInput = this.requestIdInput()
    if (ridInput) ridInput.value = submittedRequestId

    const form = event?.target || this.element.querySelector("#posting-form")
    const formData = new FormData(form)
    formData.set("request_id", submittedRequestId)
    const state = this.getState()
    formData.set("amount_cents", this.effectiveAmountCents().toString())
    if (state.transactionType === "draft") {
      const draftAccountCents = state.draftAmounts?.draftAccountCents ?? 0
      let primaryRef = state.primaryAccountReference?.trim() ?? ""
      if (draftAccountCents === 0 || !primaryRef) primaryRef = "0"
      formData.set("primary_account_reference", primaryRef)
    }
    this.appendEntries(formData)

    const advisoryCheck = await this.checkAdvisories(state)
    if (!advisoryCheck.ok) {
      this.setHeaderState("Blocked")
      this.renderMessage(advisoryCheck.error || "Posting blocked.", "error")
      return
    }
    if (advisoryCheck.requiresAcknowledgment) {
      this.element.dispatchEvent(new CustomEvent("tx:advisory-required", {
        bubbles: true,
        detail: {
          advisory: advisoryCheck.advisory,
          formData,
          url: form.action,
          requestId: submittedRequestId
        }
      }))
      this.setHeaderState("Advisory Required")
      this.renderMessage("Acknowledge the advisory to continue.", "warning")
      return
    }

    try {
      this.setHeaderState("Posting")
      this.element.dispatchEvent(new CustomEvent("tx:posting-started", {
        bubbles: true,
        detail: {
          requestId: submittedRequestId,
          transactionType: this.transactionTypeTarget.value
        }
      }))
      const postingResult = await this.requestPosting({
        url: form.action,
        formData,
        requestId: submittedRequestId
      })

      if (!postingResult.ok) {
        this.setHeaderState("Blocked")
        this.renderMessage(postingResult.error || "Posting failed.", "error")
        return
      }

      this.clearTransactionFormAfterPost()
      this.renderMessage(`${this.transactionTypeLabel()} posted.`, "success")
      this.showPostSuccessModal({
        requestId: postingResult.requestId,
        postingBatchId: postingResult.postingBatchId,
        tellerTransactionId: postingResult.tellerTransactionId
      })
      this.postedLocked = true
      this.setSubmitButtonsDisabled(true)
      this.setHeaderState("Posted")
    } catch (error) {
      this.setHeaderState("Blocked")
      this.renderMessage(`Posting failed: ${error.message}`, "error")
    }
  }

  buildValidationFormData() {
    this.ensureRequestId()
    const state = this.getState()
    const formData = new FormData()
    formData.set("request_id", this.requestIdInput()?.value || this.generateRequestId())
    formData.set("transaction_type", state.transactionType)
    formData.set("amount_cents", String(state.effectiveAmountCents))
    let primaryRef = state.primaryAccountReference?.trim() ?? ""
    if (state.transactionType === "draft") {
      const draftAccountCents = state.draftAmounts?.draftAccountCents ?? 0
      if (draftAccountCents === 0 || !primaryRef) primaryRef = "0"
    }
    formData.set("primary_account_reference", primaryRef)
    formData.set("counterparty_account_reference", state.counterpartyAccountReference ?? "")
    formData.set("cash_account_reference", state.cashAccountReference ?? "")
    appendEntriesAndTypePayload(formData, state.transactionType, state, this.workflowSchema)
    return formData
  }

  requestValidation() {
    const requestId = this.requestIdInput()?.value
    const formData = this.buildValidationFormData()

    return new Promise((resolve) => {
      const onValidated = (event) => {
        cleanup()
        resolve(event.detail || { ok: false, errors: ["Validation failed"] })
      }

      const onValidationFailed = (event) => {
        cleanup()
        resolve({ ok: false, errors: event.detail?.errors || ["Validation failed"] })
      }

      const cleanup = () => {
        this.element.removeEventListener("tx:validated", onValidated)
        this.element.removeEventListener("tx:validation-failed", onValidationFailed)
      }

      this.element.addEventListener("tx:validated", onValidated)
      this.element.addEventListener("tx:validation-failed", onValidationFailed)

      this.element.dispatchEvent(new CustomEvent("tx:validate-requested", {
        bubbles: true,
        detail: {
          requestId,
          transactionType: this.transactionTypeTarget.value,
          url: this.validateUrlValue,
          formData
        }
      }))
    })
  }

  async checkAdvisories(state) {
    if (!this.hasAdvisoriesUrlValue) {
      return { ok: true }
    }

    const primaryRef = (state.primaryAccountReference ?? "").trim()
    const partyId = (state.partyId ?? "").trim()
    if (!primaryRef && !partyId) {
      return { ok: true }
    }

    const url = new URL(this.advisoriesUrlValue, window.location.origin)
    if (partyId) {
      url.searchParams.set("party_id", partyId)
    } else if (primaryRef && !primaryRef.includes(":")) {
      url.searchParams.set("account_reference", primaryRef)
    } else {
      return { ok: true }
    }

    try {
      const response = await fetch(url.toString(), { headers: { Accept: "application/json" } })
      const body = await response.json()
      if (!response.ok || !body.ok) {
        return { ok: false, error: "Unable to verify advisories." }
      }

      const advisories = body.advisories || []
      const restriction = advisories.find((a) => a.severity === "restriction")
      if (restriction) {
        return { ok: false, error: "Transaction restricted: " + (restriction.title || "An advisory restricts this transaction.") }
      }

      const unacked = advisories.find((a) => a.severity === "requires_acknowledgment" && !a.acknowledged)
      if (unacked) {
        return { ok: true, requiresAcknowledgment: true, advisory: unacked }
      }

      return { ok: true }
    } catch {
      return { ok: false, error: "Unable to verify advisories." }
    }
  }

  async handlePostAfterAdvisory(event) {
    const { formData, url, requestId } = event.detail || {}
    if (!formData || !url) return

    this.setHeaderState("Posting")
    this.element.dispatchEvent(new CustomEvent("tx:posting-started", {
      bubbles: true,
      detail: { requestId, transactionType: this.transactionTypeTarget.value }
    }))

    const result = await this.requestPosting({ url, formData, requestId })
    if (result.ok) {
      this.clearTransactionFormAfterPost()
      this.renderMessage(`${this.transactionTypeLabel()} posted.`, "success")
      this.showPostSuccessModal({
        requestId: result.requestId,
        postingBatchId: result.postingBatchId,
        tellerTransactionId: result.tellerTransactionId
      })
      this.postedLocked = true
      this.setSubmitButtonsDisabled(true)
      this.setHeaderState("Posted")
    } else {
      this.setHeaderState("Blocked")
      this.renderMessage(result.error || "Posting failed.", "error")
    }
  }

  handleAdvisoryError(event) {
    this.setHeaderState("Editing")
    this.renderMessage(event.detail?.message || "Advisory acknowledgment failed.", "error")
  }

  requestPosting({ url, formData, requestId }) {
    return new Promise((resolve) => {
      const onPosted = (event) => {
        cleanup()
        resolve({ ok: true, ...(event.detail || {}) })
      }

      const onPostFailed = (event) => {
        cleanup()
        resolve({ ok: false, error: event.detail?.error || "Posting failed." })
      }

      const cleanup = () => {
        this.element.removeEventListener("tx:posted-success", onPosted)
        this.element.removeEventListener("tx:posted-failed", onPostFailed)
      }

      this.element.addEventListener("tx:posted-success", onPosted)
      this.element.addEventListener("tx:posted-failed", onPostFailed)

      this.element.dispatchEvent(new CustomEvent("tx:post-requested", {
        bubbles: true,
        detail: { requestId, url, formData }
      }))
    })
  }

  resetForm() {
    this.postedLocked = false
    this.transactionTypeTarget.value = this.defaultTransactionTypeValue || "deposit"
    this.element.dispatchEvent(new CustomEvent("tx:form-reset", { bubbles: true }))
    this.approvalTokenTarget.value = ""
    this.resetFormFieldClearing()
    this.resetReceipt()
    this.clearMessage()
    this.element.dispatchEvent(new CustomEvent("tx:approval-cleared", { bubbles: true }))
    this.setHeaderState("Editing")
    this.ensureRequestId()
    this.recalculate()
    this.focusFirstField()
  }

  startNewTransaction() {
    this.postedLocked = false
    this.clearTransactionFormAfterPost()
    this.resetReceipt()
    this.clearMessage()
    this.setSubmitButtonsDisabled(false)
    this.setHeaderState("Editing")
    this.focusFirstField()
  }

  showPostSuccessModal({ requestId, postingBatchId, tellerTransactionId }) {
    if (!this.hasPostSuccessModalTarget) return
    if (this.hasPostSuccessIdsTarget) {
      const parts = []
      if (postingBatchId != null) parts.push(`Batch: ${postingBatchId}`)
      if (tellerTransactionId != null) parts.push(`Txn: ${tellerTransactionId}`)
      this.postSuccessIdsTarget.textContent = parts.length ? parts.join(" · ") : ""
    }
    if (this.hasPostSuccessReceiptLinkTarget && this.hasReceiptUrlTemplateValue && requestId) {
      this.postSuccessReceiptLinkTarget.href = this.receiptUrlTemplateValue.replace("__REQUEST_ID__", encodeURIComponent(requestId))
    }
    if (typeof this.postSuccessModalTarget.showModal === "function") {
      this.postSuccessModalTarget.showModal()
    } else {
      this.postSuccessModalTarget.setAttribute("open", "open")
    }
    if (this.hasPostSuccessNewButtonTarget && typeof this.postSuccessNewButtonTarget.focus === "function") {
      this.postSuccessNewButtonTarget.focus()
    }
  }

  closePostSuccessAndStartNew() {
    if (this.hasPostSuccessModalTarget) {
      if (typeof this.postSuccessModalTarget.close === "function") {
        this.postSuccessModalTarget.close()
      } else {
        this.postSuccessModalTarget.removeAttribute("open")
      }
    }
    this.startNewTransaction()
  }

  handlePostSuccessModalClosed() {
    if (this.postedLocked) {
      this.startNewTransaction()
    }
  }

  clearTransactionFormAfterPost() {
    this.element.dispatchEvent(new CustomEvent("tx:form-reset", { bubbles: true }))
    const approvalInput = this.hasApprovalTokenTarget ? this.approvalTokenTarget : this.element.querySelector('input[name="approval_token"]')
    if (approvalInput) approvalInput.value = ""
    const requestIdInput = this.requestIdInput()
    if (requestIdInput) requestIdInput.value = this.generateRequestId()
    this.element.dispatchEvent(new CustomEvent("tx:approval-cleared", { bubbles: true }))
    this.resetFormFieldClearing(true)
    this.recalculate()
  }

  handleApprovalGranted(event) {
    const token = event.detail?.approvalToken || ""
    this.approvalTokenTarget.value = token
    this.submitButtonTarget.disabled = false
    if (this.hasHeaderSubmitButtonTarget) {
      this.headerSubmitButtonTarget.disabled = false
    }
    this.setHeaderState("Editing")
    this.renderMessage("Supervisor approval captured. You can now post the transaction.", "success")
  }

  handleApprovalError(event) {
    this.renderMessage(event.detail?.message || "Approval failed", "error")
  }

  setBalanceBadge(state) {
    if (!this.hasStatusBadgeTarget) return
    this.statusBadgeTarget.textContent = state
    this.setBadgeVariant(this.statusBadgeTarget, state === "Balanced" ? "success" : "error")
  }

  setHeaderState(state) {
    if (this.hasHeaderStateBadgeTarget) {
      this.headerStateBadgeTarget.textContent = state
      if (["Blocked", "Out of Balance"].includes(state)) {
        this.setBadgeVariant(this.headerStateBadgeTarget, "error")
      } else if (state === "Approval Required") {
        this.setBadgeVariant(this.headerStateBadgeTarget, "warning")
      } else if (["Balanced", "Posted"].includes(state)) {
        this.setBadgeVariant(this.headerStateBadgeTarget, "success")
      } else {
        this.setBadgeVariant(this.headerStateBadgeTarget, "neutral")
      }
    }

    if (this.hasHeaderStatusTarget) {
      this.headerStatusTarget.textContent = state
    }
  }

  ensureRequestId() {
    const input = this.hasRequestIdTarget ? this.requestIdTarget : this.element.querySelector('input[name="request_id"]')
    if (input && !input.value) {
      input.value = this.generateRequestId()
    }
  }

  requestIdInput() {
    return this.hasRequestIdTarget ? this.requestIdTarget : this.element.querySelector('input[name="request_id"]')
  }

  generateRequestId() {
    return `ui-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  }

  transactionTypeLabel() {
    const transactionType = this.transactionTypeTarget.value || "transaction"
    const schemaLabel = this.workflowSchema?.[transactionType]?.label
    if (schemaLabel) return schemaLabel
    return transactionType.charAt(0).toUpperCase() + transactionType.slice(1)
  }

  workflowSections(transactionType) {
    return getSections(transactionType, this.workflowSchema)
  }

  workflowEntryProfile(transactionType) {
    return getEntryProfile(transactionType, this.workflowSchema)
  }

  workflowAmountInputMode(transactionType) {
    return getAmountInputMode(transactionType, this.workflowSchema)
  }

  workflowEffectiveAmountSource(transactionType) {
    return getEffectiveAmountSource(transactionType, this.workflowSchema)
  }

  workflowCashImpactProfile(transactionType) {
    return getCashImpactProfile(transactionType, this.workflowSchema)
  }

  workflowRequiresPrimaryAccount(transactionType, context = {}) {
    return getRequiresPrimaryAccount(transactionType, this.workflowSchema, context)
  }

  workflowRequiresCounterpartyAccount(transactionType) {
    return getRequiresCounterpartyAccount(transactionType, this.workflowSchema)
  }

  workflowRequiresCashAccount(transactionType, context = {}) {
    return getRequiresCashAccount(transactionType, this.workflowSchema, context)
  }

  workflowRequiresSettlementAccount(transactionType) {
    return getRequiresSettlementAccount(transactionType, this.workflowSchema)
  }

  workflowHasSection(transactionType, sectionKey, schemaSections = null) {
    return workflowHasSectionInConfig(transactionType, sectionKey, schemaSections ?? getSections(transactionType, this.workflowSchema))
  }

  clearMessage() {
    this.renderMessage("", "info")
  }

  renderMessage(message, variant) {
    if (!this.hasMessageTarget) return

    this.messageTarget.classList.add("alert")
    this.messageTarget.classList.remove("alert-success", "alert-warning", "alert-error", "alert-info")
    this.messageTarget.classList.add(this.alertClass(variant))
    this.messageTarget.textContent = message
    this.messageTarget.hidden = message.length === 0
    this.messageTarget.classList.toggle("hidden", message.length === 0)
  }

  alertClass(variant) {
    if (variant === "success") return "alert-success"
    if (variant === "warning") return "alert-warning"
    if (variant === "error") return "alert-error"
    return "alert-info"
  }

  appendEntries(formData) {
    const state = this.getState()
    appendEntriesAndTypePayload(formData, state.transactionType, state, this.workflowSchema)
  }

  formatCents(cents) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD"
    }).format((Number(cents) || 0) / 100)
  }

  renderPostingPreview(entries) {
    const body = this.postingPreviewBodyTarget
    const empty = this.hasPostingPreviewEmptyTarget ? this.postingPreviewEmptyTarget : null

    body.innerHTML = ""
    if (empty) empty.hidden = entries.length > 0

    entries.forEach((entry) => {
      const tr = document.createElement("tr")
      tr.className = "row-border"
      const leg = entry.side === "debit" ? "Debit" : "Credit"
      const debit = entry.side === "debit" ? this.formatCents(entry.amount_cents) : "—"
      const credit = entry.side === "credit" ? this.formatCents(entry.amount_cents) : "—"
      const ref = String(entry.account_reference || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
      tr.innerHTML = `
        <td class="py-2">${leg}</td>
        <td class="py-2 mono text-xs text-slate-600">${ref}</td>
        <td class="py-2 text-right mono tabular-nums">${debit}</td>
        <td class="py-2 text-right mono tabular-nums">${credit}</td>
      `
      body.appendChild(tr)
    })
  }

  populateGovtIdFromParty(event) {
    if (!this.hasIdTypeTarget || !this.hasIdNumberTarget) return
    const { govt_id_type, govt_id } = event.detail || {}
    this.idTypeTarget.value = govt_id_type || ""
    this.idNumberTarget.value = govt_id || ""
    this.recalculate()
  }

  setAmountCents(target, cents) {
    const value = String(Math.max(0, parseInt(cents, 10) || 0))
    const wrapper = target.closest?.("[data-controller~=\"currency-input\"]")
    if (wrapper) {
      wrapper.dispatchEvent(new CustomEvent("currency:set", { bubbles: true, detail: { cents: value } }))
    } else {
      target.value = value
    }
  }

  showReceipt({ postingBatchId, tellerTransactionId, requestId, postedAt }) {
    if (!this.hasReceiptPanelTarget) return

    if (this.hasReceiptBatchIdTarget) this.receiptBatchIdTarget.textContent = postingBatchId?.toString() || "N/A"
    if (this.hasReceiptTransactionIdTarget) this.receiptTransactionIdTarget.textContent = tellerTransactionId?.toString() || "N/A"
    if (this.hasReceiptRequestIdTarget) this.receiptRequestIdTarget.textContent = requestId || "N/A"
    if (this.hasReceiptPostedAtTarget) this.receiptPostedAtTarget.textContent = postedAt || "N/A"

    this.receiptPanelTarget.removeAttribute("hidden")
    this.receiptPanelTarget.style.display = ""
    this.receiptPanelTarget.classList.remove("hidden")

    if (this.hasReceiptLinkTarget && this.hasReceiptUrlTemplateValue && requestId) {
      this.receiptLinkTarget.removeAttribute("hidden")
      this.receiptLinkTarget.style.display = ""
      this.receiptLinkTarget.classList.remove("hidden")
      this.receiptLinkTarget.href = this.receiptUrlTemplateValue.replace("__REQUEST_ID__", encodeURIComponent(requestId))
    }

    if (this.hasReceiptNewButtonTarget) {
      this.receiptNewButtonTarget.removeAttribute("hidden")
      this.receiptNewButtonTarget.style.display = ""
      this.receiptNewButtonTarget.classList.remove("hidden")
      this.receiptNewButtonTarget.focus()
    }

    requestAnimationFrame(() => {
      this.receiptPanelTarget?.scrollIntoView({ behavior: "smooth", block: "nearest" })
    })
  }

  resetReceipt() {
    if (!this.hasReceiptPanelTarget) return

    this.receiptBatchIdTarget.textContent = "N/A"
    this.receiptTransactionIdTarget.textContent = "N/A"
    this.receiptRequestIdTarget.textContent = "N/A"
    this.receiptPostedAtTarget.textContent = "N/A"

    if (this.hasReceiptLinkTarget) {
      this.receiptLinkTarget.hidden = true
      this.receiptLinkTarget.href = "#"
    }

    if (this.hasReceiptNewButtonTarget) {
      this.receiptNewButtonTarget.hidden = true
    }

    this.receiptPanelTarget.hidden = true
  }

  setSubmitButtonsDisabled(disabled) {
    this.submitButtonTarget.disabled = disabled
    if (this.hasHeaderSubmitButtonTarget) {
      this.headerSubmitButtonTarget.disabled = disabled
    }
  }

  setBadgeVariant(element, variant) {
    element.classList.add("badge")
    element.classList.remove("badge-success", "badge-error", "badge-warning", "badge-neutral")

    if (variant === "success") {
      element.classList.add("badge-success")
      return
    }
    if (variant === "warning") {
      element.classList.add("badge-warning")
      return
    }
    if (variant === "error") {
      element.classList.add("badge-error")
      return
    }
    element.classList.add("badge-neutral")
  }
}
