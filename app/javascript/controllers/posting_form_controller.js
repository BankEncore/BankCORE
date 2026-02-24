import { Controller } from "@hotwired/stimulus"
import { buildEntries, computeTotals } from "services/posting_balance"
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
  getRequiresParty,
  hasSection as workflowHasSectionInConfig,
  blockedReason as workflowBlockedReason
} from "services/posting_workflows"
import { appendEntriesAndTypePayload } from "services/posting_payload"

export default class extends Controller {
  static targets = [
    "transactionType",
    "requestId",
    "approvalToken",
    "primaryAccountReference",
    "counterpartyAccountReference",
    "counterpartyRow",
    "cashAccountReference",
    "cashAccountRow",
    "checkSection",
    "draftSection",
    "vaultTransferSection",
    "checkCashingSection",
    "partyId",
    "checkCashingIdRow",
    "checkRows",
    "checkTemplate",
    "amountCents",
    "cashAmountRow",
    "primaryAccountRow",
    "checkAmountCents",
    "feeCents",
    "settlementAccountReference",
    "feeIncomeAccountReference",
    "draftFundingSource",
    "draftAmountCents",
    "draftFeeCents",
    "draftPayeeName",
    "draftInstrumentNumber",
    "draftLiabilityAccountReference",
    "draftFeeIncomeAccountReference",
    "vaultTransferFromReference",
    "vaultTransferToReference",
    "vaultTransferReasonCode",
    "vaultTransferMemo",
    "checkNumber",
    "routingNumber",
    "accountNumber",
    "payerName",
    "presenterType",
    "idType",
    "idNumber",
    "headerStatus",
    "statusBadge",
    "cashSubtotal",
    "checkSubtotal",
    "totalAmount",
    "debitTotal",
    "creditTotal",
    "imbalance",
    "cashImpact",
    "projectedDrawer",
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
    "postingPreviewSection",
    "postingPreviewBody",
    "postingPreviewEmpty",
    "computedCashSubtotal",
    "computedCheckSubtotal",
    "computedFeeSubtotal",
    "computedNetTotal",
    "primaryReferenceValue",
    "primaryStatus",
    "primaryLedger",
    "primaryAvailable",
    "primaryProjectedLedger",
    "primaryProjectedAvailable",
    "primaryLastPosted",
    "counterpartyReferencePanel",
    "counterpartyReferenceValue",
    "counterpartyStatus",
    "counterpartyLedger",
    "counterpartyAvailable",
    "counterpartyProjectedLedger",
    "counterpartyProjectedAvailable",
    "counterpartyLastPosted",
    "cashReferenceValue",
    "cashStatus",
    "cashLedger",
    "cashAvailable",
    "cashProjectedLedger",
    "cashProjectedAvailable",
    "cashLastPosted",
    "referenceAlerts",
    "referenceRestrictions",
    "accountHistoryList",
    "thresholdWarning",
    "message"
  ]

  static values = {
    openingCashCents: Number,
    defaultTransactionType: String,
    validateUrl: String,
    accountReferenceUrl: String,
    accountHistoryUrl: String,
    workflowSchemaUrl: String,
    receiptUrlTemplate: String,
    drawerReference: String
  }

  connect() {
    this.postedLocked = false
    this.workflowSchema = null
    this.defaultCashAccountReference = this.cashAccountReferenceTarget.value
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
        headers: {
          Accept: "application/json"
        },
        credentials: "same-origin"
      })
      if (!response.ok) {
        return
      }

      const payload = await response.json()
      this.workflowSchema = payload.workflows || {}
      this.recalculate()
    } catch {
    }
  }

  getState() {
    const transactionType = this.transactionTypeTarget.value
    const checkCashingAmounts = this.checkCashingAmounts()
    const draftAmounts = this.draftAmounts()
    const vaultTransferDetails = this.vaultTransferDetails()
    const checks = this.collectCheckRows()
    const effectiveAmountCents = this.effectiveAmountCents()
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: this.primaryAccountReferenceTarget.value,
      counterpartyAccountReference: this.counterpartyAccountReferenceTarget.value,
      cashAccountReference: this.cashAccountReferenceTarget.value,
      amountCents: parseInt(this.amountCentsTarget.value || "0", 10),
      effectiveAmountCents,
      checks,
      checkCashingAmounts,
      settlementAccountReference: this.hasSettlementAccountReferenceTarget ? this.settlementAccountReferenceTarget.value : "",
      feeIncomeAccountReference: this.hasFeeIncomeAccountReferenceTarget ? this.feeIncomeAccountReferenceTarget.value : "income:check_cashing_fee",
      draftAmounts,
      draftFundingSource: this.hasDraftFundingSourceTarget ? this.draftFundingSourceTarget.value : "account",
      draftLiabilityAccountReference: this.hasDraftLiabilityAccountReferenceTarget ? this.draftLiabilityAccountReferenceTarget.value : "official_check:outstanding",
      draftFeeIncomeAccountReference: this.hasDraftFeeIncomeAccountReferenceTarget ? this.draftFeeIncomeAccountReferenceTarget.value : "income:draft_fee",
      draftPayeeName: this.hasDraftPayeeNameTarget ? this.draftPayeeNameTarget.value : "",
      draftInstrumentNumber: this.hasDraftInstrumentNumberTarget ? this.draftInstrumentNumberTarget.value : "",
      vaultTransferDetails,
      drawerReference: (this.hasDrawerReferenceValue && this.drawerReferenceValue) ? this.drawerReferenceValue : this.cashAccountReferenceTarget.value,
      checkNumber: this.hasCheckNumberTarget ? this.checkNumberTarget.value : "",
      routingNumber: this.hasRoutingNumberTarget ? this.routingNumberTarget.value : "",
      accountNumber: this.hasAccountNumberTarget ? this.accountNumberTarget.value : "",
      payerName: this.hasPayerNameTarget ? this.payerNameTarget.value : "",
      presenterType: this.hasPresenterTypeTarget ? this.presenterTypeTarget.value : "",
      idType: this.hasIdTypeTarget ? this.idTypeTarget.value : "",
      idNumber: this.hasIdNumberTarget ? this.idNumberTarget.value : "",
      partyId: this.hasPartyIdTarget ? this.partyIdTarget.value : ""
    }
  }

  recalculate() {
    const transactionType = this.transactionTypeTarget.value
    const state = this.getState()
    const schemaSections = getSections(transactionType, this.workflowSchema)
    const showCheckSectionFromWorkflow = workflowHasSectionInConfig(transactionType, "checks", schemaSections)
    const isFixedFlowDepositOrDraft = this.hasDefaultTransactionTypeValue && this.defaultTransactionTypeValue && ["deposit", "draft"].includes(this.defaultTransactionTypeValue) && (this.transactionTypeTarget.value || "") === (this.defaultTransactionTypeValue || "")
    const showCheckSection = showCheckSectionFromWorkflow || (isFixedFlowDepositOrDraft && ["deposit", "draft"].includes(transactionType))
    const showDraftSection = workflowHasSectionInConfig(transactionType, "draft", schemaSections)
    const showVaultTransferSection = workflowHasSectionInConfig(transactionType, "vault_transfer", schemaSections)
    const showCheckCashingSection = workflowHasSectionInConfig(transactionType, "check_cashing", schemaSections)
    const amountInputMode = getAmountInputMode(transactionType, this.workflowSchema)
    const checkCashingAmounts = state.checkCashingAmounts
    const draftAmounts = state.draftAmounts
    const vaultTransferDetails = state.vaultTransferDetails

    if (amountInputMode === "check_cashing_net_payout") {
      this.setAmountCents(this.amountCentsTarget, checkCashingAmounts.netCashPayoutCents)
    } else if (amountInputMode === "draft_amount") {
      this.setAmountCents(this.amountCentsTarget, draftAmounts.draftAmountCents)
    }

    const totalAmountCents = state.effectiveAmountCents
    const workflowContext = { draftFundingSource: state.draftFundingSource }
    const hasPrimaryAccount = state.primaryAccountReference.trim().length > 0
    const requiresPrimaryAccount = getRequiresPrimaryAccount(transactionType, this.workflowSchema, workflowContext)
    const requiresCounterparty = getRequiresCounterpartyAccount(transactionType, this.workflowSchema)
    const requiresCashAccount = getRequiresCashAccount(transactionType, this.workflowSchema, workflowContext)
    const requiresSettlementAccount = getRequiresSettlementAccount(transactionType, this.workflowSchema)
    const requiresParty = getRequiresParty(transactionType, this.workflowSchema)
    const hasParty = state.partyId.trim().length > 0
    const requiresDraftDetails = showDraftSection
    const requiresVaultTransferDetails = showVaultTransferSection
    const hasCounterparty = state.counterpartyAccountReference.trim().length > 0
    const hasCashAccount = state.cashAccountReference.trim().length > 0
    const hasSettlementAccount = state.settlementAccountReference.trim().length > 0
    const hasDraftPayee = state.draftPayeeName.trim().length > 0
    const hasDraftInstrumentNumber = state.draftInstrumentNumber.trim().length > 0
    const hasDraftLiabilityAccount = state.draftLiabilityAccountReference.trim().length > 0
    const hasVaultDirection = vaultTransferDetails.direction.length > 0
    const hasVaultReasonCode = vaultTransferDetails.reasonCode.length > 0
    const hasVaultMemo = vaultTransferDetails.reasonCode !== "other" || vaultTransferDetails.memo.length > 0
    const hasVaultEndpoints = vaultTransferDetails.valid
    const hasInvalidCheckRows = this.hasInvalidCheckRows()
    const hasInvalidCheckCashingFields = this.hasInvalidCheckCashingFields(checkCashingAmounts)
    const hasInvalidDraftFields = this.hasInvalidDraftFields(draftAmounts)
    const hasInvalidVaultTransferFields = this.hasInvalidVaultTransferFields(vaultTransferDetails)
    const hasMissingFields = totalAmountCents <= 0 || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCounterparty && !hasCounterparty) || (requiresCashAccount && !hasCashAccount) || (requiresSettlementAccount && !hasSettlementAccount) || (requiresParty && !hasParty) || (requiresDraftDetails && (!hasDraftPayee || !hasDraftInstrumentNumber || !hasDraftLiabilityAccount)) || (requiresVaultTransferDetails && (!hasVaultDirection || !hasVaultReasonCode || !hasVaultMemo || !hasVaultEndpoints)) || hasInvalidCheckRows || hasInvalidCheckCashingFields || hasInvalidDraftFields || hasInvalidVaultTransferFields

    const entries = buildEntries(transactionType, state)
    const { debitTotal, creditTotal, imbalance, balanced } = computeTotals(entries)
    const checkSubtotalCents = this.checkSubtotalCents()
    const displayedCashAmount = showCheckCashingSection ? checkCashingAmounts.netCashPayoutCents : Math.max(state.amountCents, 0)
    const blockedReason = workflowBlockedReason({
      totalAmountCents,
      hasPrimaryAccount,
      requiresPrimaryAccount,
      requiresCounterparty,
      hasCounterparty,
      requiresCashAccount,
      hasCashAccount,
      requiresSettlementAccount,
      hasSettlementAccount,
      requiresParty,
      hasParty,
      requiresDraftDetails,
      hasDraftPayee,
      hasDraftInstrumentNumber,
      hasDraftLiabilityAccount,
      requiresVaultTransferDetails,
      hasVaultDirection,
      hasVaultReasonCode,
      hasVaultMemo,
      hasVaultEndpoints,
      hasInvalidCheckRows,
      hasInvalidCheckCashingFields,
      hasInvalidDraftFields,
      hasInvalidVaultTransferFields,
      balanced
    })

    this.counterpartyRowTarget.hidden = !requiresCounterparty
    if (this.hasCashAccountRowTarget) {
      this.cashAccountRowTarget.hidden = !requiresCashAccount
    }
    if (this.hasCheckSectionTarget) {
      this.checkSectionTarget.hidden = !showCheckSection
    }
    if (this.hasDraftSectionTarget) {
      this.draftSectionTarget.hidden = !showDraftSection
    }
    if (this.hasVaultTransferSectionTarget) {
      this.vaultTransferSectionTarget.hidden = !showVaultTransferSection
    }
    if (this.hasCheckCashingSectionTarget) {
      this.checkCashingSectionTarget.hidden = !showCheckCashingSection
    }
    this.setDraftFieldState(showDraftSection)
    this.setVaultTransferFieldState(showVaultTransferSection)
    this.setCheckCashingFieldState(showCheckCashingSection)
    this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
    this.primaryAccountReferenceTarget.setAttribute("aria-required", requiresPrimaryAccount ? "true" : "false")
    this.amountCentsTarget.readOnly = showCheckCashingSection || showDraftSection
    if (this.hasSettlementAccountReferenceTarget) {
      this.settlementAccountReferenceTarget.required = requiresSettlementAccount
      this.settlementAccountReferenceTarget.setAttribute("aria-required", requiresSettlementAccount ? "true" : "false")
    }
    if (this.hasIdNumberTarget) {
      const idRequired = showCheckCashingSection && !hasParty
      this.idNumberTarget.required = idRequired
      this.idNumberTarget.setAttribute("aria-required", idRequired ? "true" : "false")
    }
    if (this.hasCheckCashingIdRowTarget) {
      this.checkCashingIdRowTarget.hidden = !showCheckCashingSection
    }
    if (this.hasPrimaryAccountRowTarget) {
      this.primaryAccountRowTarget.hidden = showCheckCashingSection
    }
    if (this.hasCashAmountRowTarget) {
      this.cashAmountRowTarget.hidden = showCheckCashingSection
    }

    if (this.hasCashSubtotalTarget) this.cashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    if (this.hasCheckSubtotalTarget) this.checkSubtotalTarget.textContent = this.formatCents(checkSubtotalCents)
    if (this.hasComputedCashSubtotalTarget) this.computedCashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    if (this.hasComputedCheckSubtotalTarget) this.computedCheckSubtotalTarget.textContent = this.formatCents(checkSubtotalCents)
    const feeCentsForComputed = showCheckCashingSection ? checkCashingAmounts.feeCents : (showDraftSection ? draftAmounts.draftFeeCents : 0)
    if (this.hasComputedFeeSubtotalTarget) this.computedFeeSubtotalTarget.textContent = feeCentsForComputed > 0 ? `-${this.formatCents(feeCentsForComputed)}` : this.formatCents(0)
    if (this.hasComputedNetTotalTarget) this.computedNetTotalTarget.textContent = this.formatCents(totalAmountCents)
    if (this.hasDebitTotalTarget) this.debitTotalTarget.textContent = this.formatCents(debitTotal)
    if (this.hasCreditTotalTarget) this.creditTotalTarget.textContent = this.formatCents(creditTotal)
    if (this.hasImbalanceTarget) this.imbalanceTarget.textContent = this.formatCents(imbalance)
    if (this.hasTotalAmountTarget) this.totalAmountTarget.textContent = this.formatCents(totalAmountCents)
    if (this.hasStatusBadgeTarget) {
      this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    }
    if (this.hasHeaderStatusTarget) {
      this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"
    }

    const cashImpact = this.calculateCashImpact(displayedCashAmount)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    if (this.hasCashImpactTarget) this.cashImpactTarget.textContent = this.formatCents(cashImpact)
    if (this.hasProjectedDrawerTarget) this.projectedDrawerTarget.textContent = this.formatCents(projectedDrawer)

    if (this.hasThresholdWarningTarget) {
      this.thresholdWarningTarget.hidden = totalAmountCents < 100_000
    }

    let disabled = blockedReason.length > 0 || !balanced || hasMissingFields
    if (this.postedLocked) {
      disabled = true
    }
    this.submitButtonTarget.disabled = disabled
    if (this.hasHeaderSubmitButtonTarget) {
      this.headerSubmitButtonTarget.disabled = disabled
    }

    if (balanced) {
      this.setHeaderState("Balanced")
    } else {
      this.setHeaderState("Editing")
    }

    if (this.hasPostingPreviewBodyTarget) {
      this.renderPostingPreview(entries)
    }

    this.element.dispatchEvent(new CustomEvent("tx:recalc", {
      bubbles: true,
      detail: {
        transactionType,
        entries,
        primaryReference: this.primaryAccountReferenceTarget.value.trim(),
        counterpartyReference: this.counterpartyAccountReferenceTarget.value.trim(),
        cashReference: this.cashAccountReferenceTarget.value.trim(),
        requestId: this.requestIdTarget.value,
        cashAmountCents: displayedCashAmount,
        checkAmountCents: checkCashingAmounts.checkAmountCents,
        feeCents: checkCashingAmounts.feeCents,
        draftAmountCents: draftAmounts.draftAmountCents,
        draftFeeCents: draftAmounts.draftFeeCents,
        checkSubtotalCents,
        totalAmountCents,
        debitTotal,
        creditTotal,
        imbalanceCents: imbalance,
        cashImpactCents: cashImpact,
        projectedDrawerCents: projectedDrawer,
        readyToPost: !disabled,
        blockedReason
      }
    }))
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

    this.ensureRequestId()
    const form = event.target
    const formData = new FormData(form)
    const submittedRequestId = this.requestIdTarget.value || this.generateRequestId()
    formData.set("request_id", submittedRequestId)
    formData.set("amount_cents", this.effectiveAmountCents().toString())
    this.appendEntries(formData)

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
    formData.set("request_id", this.requestIdTarget.value || this.generateRequestId())
    formData.set("transaction_type", state.transactionType)
    formData.set("amount_cents", String(state.effectiveAmountCents))
    formData.set("primary_account_reference", state.primaryAccountReference)
    formData.set("counterparty_account_reference", state.counterpartyAccountReference)
    formData.set("cash_account_reference", state.cashAccountReference)
    appendEntriesAndTypePayload(formData, state.transactionType, state, this.workflowSchema)
    return formData
  }

  requestValidation() {
    const requestId = this.requestIdTarget.value
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
        detail: {
          requestId,
          url,
          formData
        }
      }))
    })
  }

  resetForm() {
    this.postedLocked = false
    this.transactionTypeTarget.value = this.defaultTransactionTypeValue || "deposit"
    this.primaryAccountReferenceTarget.value = ""
    this.counterpartyAccountReferenceTarget.value = ""
    this.setAmountCents(this.amountCentsTarget, 0)
    this.approvalTokenTarget.value = ""
    this.checkRowsTarget.innerHTML = ""
    this.resetDraftFields()
    this.resetVaultTransferFields()
    this.resetCheckCashingFields()
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
    // When dialog is closed via backdrop or escape, ensure form is ready for next transaction
    if (this.postedLocked) {
      this.startNewTransaction()
    }
  }

  clearTransactionFormAfterPost() {
    this.primaryAccountReferenceTarget.value = ""
    this.counterpartyAccountReferenceTarget.value = ""
    this.setAmountCents(this.amountCentsTarget, 0)
    this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    this.approvalTokenTarget.value = ""
    this.checkRowsTarget.innerHTML = ""
    this.resetDraftFields()
    this.resetVaultTransferFields()
    this.resetCheckCashingFields()
    this.requestIdTarget.value = this.generateRequestId()
    this.element.dispatchEvent(new CustomEvent("tx:approval-cleared", { bubbles: true }))
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
    if (!this.hasStatusBadgeTarget) {
      return
    }
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
    if (!this.requestIdTarget.value) {
      this.requestIdTarget.value = this.generateRequestId()
    }
  }

  calculateCashImpact(amountCents) {
    const transactionType = this.transactionTypeTarget.value
    const cashImpactProfile = getCashImpactProfile(transactionType, this.workflowSchema)

    if (cashImpactProfile === "inflow") return amountCents
    if (cashImpactProfile === "draft_funding") {
      if (this.draftCashFunding()) return this.draftAmounts().totalFundingCents
      return 0
    }
    if (cashImpactProfile === "vault_directional") {
      const amt = Math.max(parseInt(this.amountCentsTarget.value || "0", 10), 0)
      const direction = this.vaultTransferDetails().direction
      if (direction === "drawer_to_vault") return -amt
      if (direction === "vault_to_drawer") return amt
      return 0
    }
    if (cashImpactProfile === "outflow") return -amountCents
    return 0
  }

  generateRequestId() {
    return `ui-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  }

  transactionTypeLabel() {
    const transactionType = this.transactionTypeTarget.value || "transaction"
    const schemaLabel = this.workflowSchema?.[transactionType]?.label
    if (schemaLabel) {
      return schemaLabel
    }

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

  workflowRequiresPrimaryAccount(transactionType) {
    return getRequiresPrimaryAccount(transactionType, this.workflowSchema, { draftFundingSource: this.hasDraftFundingSourceTarget ? this.draftFundingSourceTarget.value : "account" })
  }

  workflowRequiresCounterpartyAccount(transactionType) {
    return getRequiresCounterpartyAccount(transactionType, this.workflowSchema)
  }

  workflowRequiresCashAccount(transactionType) {
    return getRequiresCashAccount(transactionType, this.workflowSchema, { draftFundingSource: this.hasDraftFundingSourceTarget ? this.draftFundingSourceTarget.value : "account" })
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
    if (!this.hasMessageTarget) {
      return
    }

    this.messageTarget.classList.add("alert")
    this.messageTarget.classList.remove("alert-success", "alert-warning", "alert-error", "alert-info")
    this.messageTarget.classList.add(this.alertClass(variant))
    this.messageTarget.textContent = message
    this.messageTarget.hidden = message.length === 0
    this.messageTarget.classList.toggle("hidden", message.length === 0)
  }

  alertClass(variant) {
    if (variant === "success") {
      return "alert-success"
    }

    if (variant === "warning") {
      return "alert-warning"
    }

    if (variant === "error") {
      return "alert-error"
    }

    return "alert-info"
  }

  appendEntries(formData) {
    const state = this.getState()
    appendEntriesAndTypePayload(formData, state.transactionType, state, this.workflowSchema)
  }

  effectiveAmountCents() {
    const transactionType = this.transactionTypeTarget.value
    const amountSource = getEffectiveAmountSource(transactionType, this.workflowSchema)

    if (amountSource === "check_cashing_net_payout") {
      return this.checkCashingAmounts().netCashPayoutCents
    }

    const baseAmount = parseInt(this.amountCentsTarget.value || "0", 10)

    if (amountSource === "cash_plus_checks") {
      return Math.max(baseAmount, 0) + this.checkSubtotalCents()
    }

    return Math.max(baseAmount, 0)
  }

  checkCashingAmounts() {
    const checkSubtotalCents = this.checkSubtotalCents()
    const feeCents = this.hasFeeCentsTarget ? Math.max(parseInt(this.feeCentsTarget.value || "0", 10), 0) : 0

    return {
      checkAmountCents: checkSubtotalCents,
      feeCents,
      netCashPayoutCents: Math.max(checkSubtotalCents - feeCents, 0)
    }
  }

  draftAmounts() {
    const draftAmountCents = this.hasDraftAmountCentsTarget ? Math.max(parseInt(this.draftAmountCentsTarget.value || "0", 10), 0) : 0
    const draftFeeCents = this.hasDraftFeeCentsTarget ? Math.max(parseInt(this.draftFeeCentsTarget.value || "0", 10), 0) : 0

    return {
      draftAmountCents,
      draftFeeCents,
      totalFundingCents: draftAmountCents + draftFeeCents
    }
  }

  draftFundingSource() {
    return this.hasDraftFundingSourceTarget ? this.draftFundingSourceTarget.value.trim() : "account"
  }

  draftCashFunding() {
    return this.draftFundingSource() === "cash"
  }

  draftAccountFunding() {
    return !this.draftCashFunding()
  }

  vaultTransferDetails() {
    const fromRef = this.hasVaultTransferFromReferenceTarget ? this.vaultTransferFromReferenceTarget.value.trim() : ""
    const toRef = this.hasVaultTransferToReferenceTarget ? this.vaultTransferToReferenceTarget.value.trim() : ""
    const drawerRef = (this.hasDrawerReferenceValue && this.drawerReferenceValue) ? this.drawerReferenceValue.trim() : this.cashAccountReferenceTarget.value.trim()
    const reasonCode = this.hasVaultTransferReasonCodeTarget ? this.vaultTransferReasonCodeTarget.value.trim() : ""
    const memo = this.hasVaultTransferMemoTarget ? this.vaultTransferMemoTarget.value.trim() : ""

    const sourceReference = fromRef
    const destinationReference = toRef
    let direction = ""
    if (sourceReference && destinationReference && sourceReference !== destinationReference) {
      const fromIsDrawer = sourceReference === drawerRef
      const toIsDrawer = destinationReference === drawerRef
      if (fromIsDrawer && !toIsDrawer) direction = "drawer_to_vault"
      else if (!fromIsDrawer && toIsDrawer) direction = "vault_to_drawer"
      else if (!fromIsDrawer && !toIsDrawer) direction = "vault_to_vault"
    }

    const valid = direction.length > 0 && sourceReference.length > 0 && destinationReference.length > 0
    return {
      direction,
      sourceReference,
      destinationReference,
      reasonCode,
      memo,
      valid
    }
  }

  hasInvalidVaultTransferFields(details) {
    if (!this.workflowHasSection(this.transactionTypeTarget.value, "vault_transfer")) {
      return false
    }

    if (!["drawer_to_vault", "vault_to_drawer", "vault_to_vault"].includes(details.direction)) {
      return true
    }

    if (!details.reasonCode) {
      return true
    }

    if (details.reasonCode === "other" && !details.memo) {
      return true
    }

    return !details.valid
  }

  resetVaultTransferFields() {
    if (this.hasVaultTransferFromReferenceTarget) {
      this.vaultTransferFromReferenceTarget.value = ""
    }
    if (this.hasVaultTransferToReferenceTarget) {
      this.vaultTransferToReferenceTarget.value = ""
    }
    if (this.hasVaultTransferReasonCodeTarget) {
      this.vaultTransferReasonCodeTarget.value = ""
    }
    if (this.hasVaultTransferMemoTarget) {
      this.vaultTransferMemoTarget.value = ""
    }
  }

  setVaultTransferFieldState(enabled) {
    if (!this.hasVaultTransferSectionTarget) {
      return
    }

    this.vaultTransferSectionTarget
      .querySelectorAll("input, select, textarea")
      .forEach((field) => {
        field.disabled = !enabled
      })

    if (!enabled) {
      return
    }

    if (this.hasVaultTransferMemoTarget && this.hasVaultTransferReasonCodeTarget) {
      const reasonCode = this.vaultTransferReasonCodeTarget.value.trim()
      const memoRequired = reasonCode === "other"
      this.vaultTransferMemoTarget.required = memoRequired
      this.vaultTransferMemoTarget.setAttribute("aria-required", memoRequired ? "true" : "false")
    }
  }

  hasInvalidDraftFields({ draftAmountCents, draftFeeCents }) {
    if (!this.workflowHasSection(this.transactionTypeTarget.value, "draft")) {
      return false
    }

    return draftAmountCents <= 0 || draftFeeCents < 0
  }

  resetDraftFields() {
    if (this.hasDraftFundingSourceTarget) {
      this.draftFundingSourceTarget.value = "account"
    }

    if (this.hasDraftAmountCentsTarget) {
      this.setAmountCents(this.draftAmountCentsTarget, 0)
    }

    if (this.hasDraftFeeCentsTarget) {
      this.setAmountCents(this.draftFeeCentsTarget, 0)
    }

    if (this.hasDraftPayeeNameTarget) {
      this.draftPayeeNameTarget.value = ""
    }

    if (this.hasDraftInstrumentNumberTarget) {
      this.draftInstrumentNumberTarget.value = ""
    }

    if (this.hasDraftLiabilityAccountReferenceTarget) {
      this.draftLiabilityAccountReferenceTarget.value = "official_check:outstanding"
    }

    if (this.hasDraftFeeIncomeAccountReferenceTarget) {
      this.draftFeeIncomeAccountReferenceTarget.value = "income:draft_fee"
    }
  }

  setDraftFieldState(enabled) {
    if (!this.hasDraftSectionTarget) {
      return
    }

    this.draftSectionTarget
      .querySelectorAll("input, select, textarea")
      .forEach((field) => {
        if (field.dataset.alwaysEnabled === "true") {
          return
        }

        field.disabled = !enabled
      })
  }

  hasInvalidCheckCashingFields({ checkAmountCents, feeCents, netCashPayoutCents }) {
    if (!this.workflowHasSection(this.transactionTypeTarget.value, "check_cashing")) {
      return false
    }

    const hasParty = this.hasPartyIdTarget && this.partyIdTarget.value.trim().length > 0
    const hasIdType = this.hasIdTypeTarget && this.idTypeTarget.value.trim().length > 0
    const hasIdNumber = this.hasIdNumberTarget && this.idNumberTarget.value.trim().length > 0
    const idRequired = !hasParty
    const hasValidId = !idRequired || (hasIdType && hasIdNumber)

    return checkAmountCents <= 0 || feeCents < 0 || feeCents > checkAmountCents || netCashPayoutCents <= 0 || !hasValidId
  }

  resetCheckCashingFields() {
    if (this.hasFeeCentsTarget) {
      this.setAmountCents(this.feeCentsTarget, 0)
    }

    if (this.hasPartyIdTarget) {
      this.partyIdTarget.value = ""
    }

    if (this.hasIdTypeTarget) {
      this.idTypeTarget.value = "drivers_license"
    }

    if (this.hasIdNumberTarget) {
      this.idNumberTarget.value = ""
    }

    if (this.hasFeeIncomeAccountReferenceTarget) {
      this.feeIncomeAccountReferenceTarget.value = "income:check_cashing_fee"
    }
  }

  setCheckCashingFieldState(enabled) {
    if (!this.hasCheckCashingSectionTarget) {
      return
    }

    this.checkCashingSectionTarget
      .querySelectorAll("input, select, textarea")
      .forEach((field) => {
        field.disabled = !enabled
      })
  }

  checkSubtotalCents() {
    return this.collectCheckRows().reduce((sum, check) => sum + check.amount_cents, 0)
  }

  collectCheckRows() {
    return Array.from(this.checkRowsTarget.querySelectorAll("[data-check-row]")).map((row, index) => {
      const routing = row.querySelector('[data-check-field="routing"]')?.value?.trim() || ""
      const account = row.querySelector('[data-check-field="account"]')?.value?.trim() || ""
      const number = row.querySelector('[data-check-field="number"]')?.value?.trim() || ""
      const amountCents = parseInt(row.querySelector('[data-check-field="amount"]')?.value || "0", 10)

      const holdReason = row.querySelector('[data-check-field="holdReason"]')?.value?.trim() || ""
      const holdUntil = row.querySelector('[data-check-field="holdUntil"]')?.value?.trim() || ""

      return {
        routing,
        account,
        number,
        account_reference: this.checkAccountReference({ routing, account, number }, index),
        amount_cents: amountCents > 0 ? amountCents : 0,
        hold_reason: holdReason,
        hold_until: holdUntil
      }
    })
  }

  hasInvalidCheckRows() {
    if (!this.workflowHasSection(this.transactionTypeTarget.value, "checks")) {
      return false
    }

    return this.collectCheckRows().some((check) => {
      if (check.amount_cents <= 0) {
        return false
      }

      return [check.routing, check.account, check.number].some((field) => field.length === 0)
    })
  }

  checkAccountReference(check, index) {
    const routing = check.routing || "unknown-routing"
    const account = check.account || "unknown-account"
    const number = check.number || `unknown-${index + 1}`
    return `check:${routing}:${account}:${number}`
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
    if (!this.hasReceiptPanelTarget) {
      return
    }

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
    if (!this.hasReceiptPanelTarget) {
      return
    }

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

  focusFirstField() {
    const firstField = this.primaryAccountReferenceTarget || this.amountCentsTarget
    if (!firstField || typeof firstField.focus !== "function") return
    const wrapper = firstField.closest?.("[data-controller~=\"currency-input\"]")
    const displayInput = wrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
    if (displayInput && typeof displayInput.focus === "function") {
      displayInput.focus()
    } else {
      firstField.focus()
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
