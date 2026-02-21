import { Controller } from "@hotwired/stimulus"

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
    "checkCashingSection",
    "checkRows",
    "checkTemplate",
    "amountCents",
    "checkAmountCents",
    "feeCents",
    "settlementAccountReference",
    "feeIncomeAccountReference",
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
    "headerStateBadge",
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
    receiptUrlTemplate: String
  }

  connect() {
    this.postedLocked = false
    this.defaultCashAccountReference = this.cashAccountReferenceTarget.value
    if (this.hasDefaultTransactionTypeValue && this.defaultTransactionTypeValue) {
      this.transactionTypeTarget.value = this.defaultTransactionTypeValue
    }
    this.ensureRequestId()
    this.resetReceipt()
    this.clearMessage()
    this.recalculate()
  }

  recalculate() {
    const cashAmountCents = parseInt(this.amountCentsTarget.value || "0", 10)
    const checkSubtotalCents = this.checkSubtotalCents()
    const transactionType = this.transactionTypeTarget.value
    const checkCashingAmounts = this.checkCashingAmounts()
    if (transactionType === "check_cashing") {
      this.amountCentsTarget.value = checkCashingAmounts.netCashPayoutCents.toString()
    }
    const totalAmountCents = this.effectiveAmountCents()
    const hasPrimaryAccount = this.primaryAccountReferenceTarget.value.trim().length > 0
    const requiresPrimaryAccount = transactionType !== "check_cashing"
    const requiresCounterparty = transactionType === "transfer"
    const requiresCashAccount = transactionType !== "transfer"
    const requiresSettlementAccount = transactionType === "check_cashing"
    const hasCounterparty = this.counterpartyAccountReferenceTarget.value.trim().length > 0
    const hasCashAccount = this.cashAccountReferenceTarget.value.trim().length > 0
    const hasSettlementAccount = this.hasSettlementAccountReferenceTarget && this.settlementAccountReferenceTarget.value.trim().length > 0
    const hasInvalidCheckRows = this.hasInvalidCheckRows()
    const hasInvalidCheckCashingFields = this.hasInvalidCheckCashingFields(checkCashingAmounts)
    const hasMissingFields = totalAmountCents <= 0 || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCounterparty && !hasCounterparty) || (requiresCashAccount && !hasCashAccount) || (requiresSettlementAccount && !hasSettlementAccount) || hasInvalidCheckRows || hasInvalidCheckCashingFields

    const entries = this.generatedEntriesForCurrentState()
    const debitTotal = entries
      .filter((entry) => entry.side === "debit")
      .reduce((sum, entry) => sum + entry.amount_cents, 0)
    const creditTotal = entries
      .filter((entry) => entry.side === "credit")
      .reduce((sum, entry) => sum + entry.amount_cents, 0)

    const imbalance = Math.abs(debitTotal - creditTotal)
    const balanced = debitTotal > 0 && creditTotal > 0 && imbalance === 0
    const blockedReason = this.blockedReason({
      totalAmountCents,
      hasPrimaryAccount,
      requiresPrimaryAccount,
      requiresCounterparty,
      hasCounterparty,
      requiresCashAccount,
      hasCashAccount,
      requiresSettlementAccount,
      hasSettlementAccount,
      hasInvalidCheckRows,
      hasInvalidCheckCashingFields,
      balanced
    })

    this.counterpartyRowTarget.hidden = !requiresCounterparty
    if (this.hasCashAccountRowTarget) {
      this.cashAccountRowTarget.hidden = !requiresCashAccount
    }
    this.checkSectionTarget.hidden = transactionType !== "deposit"
    if (this.hasCheckCashingSectionTarget) {
      this.checkCashingSectionTarget.hidden = transactionType !== "check_cashing"
    }
    this.setCheckCashingFieldState(transactionType === "check_cashing")
    this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
    this.amountCentsTarget.readOnly = transactionType === "check_cashing"
    if (this.hasSettlementAccountReferenceTarget) {
      this.settlementAccountReferenceTarget.required = requiresSettlementAccount
    }
    if (this.hasIdNumberTarget) {
      this.idNumberTarget.required = transactionType === "check_cashing"
    }

    const displayedCashAmount = transactionType === "check_cashing" ? checkCashingAmounts.netCashPayoutCents : Math.max(cashAmountCents, 0)
    this.cashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    this.checkSubtotalTarget.textContent = this.formatCents(checkSubtotalCents)
    this.debitTotalTarget.textContent = this.formatCents(debitTotal)
    this.creditTotalTarget.textContent = this.formatCents(creditTotal)
    this.imbalanceTarget.textContent = this.formatCents(imbalance)
    this.totalAmountTarget.textContent = this.formatCents(totalAmountCents)
    this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) {
      this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"
    }

    const cashImpact = this.calculateCashImpact(displayedCashAmount)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    this.cashImpactTarget.textContent = this.formatCents(cashImpact)
    this.projectedDrawerTarget.textContent = this.formatCents(projectedDrawer)

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

  blockedReason({
    totalAmountCents,
    hasPrimaryAccount,
    requiresPrimaryAccount,
    requiresCounterparty,
    hasCounterparty,
    requiresCashAccount,
    hasCashAccount,
    requiresSettlementAccount,
    hasSettlementAccount,
    hasInvalidCheckRows,
    hasInvalidCheckCashingFields,
    balanced
  }) {
    if (totalAmountCents <= 0) {
      return "Amount must be greater than zero."
    }

    if (requiresPrimaryAccount && !hasPrimaryAccount) {
      return "Primary account reference is required."
    }

    if (requiresCounterparty && !hasCounterparty) {
      return "Counterparty account reference is required."
    }

    if (requiresSettlementAccount && !hasSettlementAccount) {
      return "Settlement account reference is required."
    }

    if (requiresCashAccount && !hasCashAccount) {
      return "Cash account reference is required."
    }

    if (hasInvalidCheckRows) {
      return "Complete check routing, account, and number for each entered check."
    }

    if (hasInvalidCheckCashingFields) {
      return "Complete check cashing amount and presenter ID details."
    }

    if (!balanced) {
      return "Entries are out of balance."
    }

    return ""
  }

  async submit(event) {
    event.preventDefault()

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

    const form = event.target
    const formData = new FormData(form)
    const submittedRequestId = this.requestIdTarget.value
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

      this.renderMessage(`${this.transactionTypeLabel()} posted.`, "success")
      this.showReceipt({
        postingBatchId: postingResult.postingBatchId,
        tellerTransactionId: postingResult.tellerTransactionId,
        requestId: postingResult.requestId,
        postedAt: postingResult.postedAt
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
    const formData = new FormData()
    formData.set("request_id", this.requestIdTarget.value)
    formData.set("transaction_type", this.transactionTypeTarget.value)
    formData.set("amount_cents", this.effectiveAmountCents().toString())
    formData.set("primary_account_reference", this.primaryAccountReferenceTarget.value)
    formData.set("counterparty_account_reference", this.counterpartyAccountReferenceTarget.value)
    formData.set("cash_account_reference", this.cashAccountReferenceTarget.value)
    this.appendEntries(formData)

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
    this.amountCentsTarget.value = "0"
    this.approvalTokenTarget.value = ""
    this.checkRowsTarget.innerHTML = ""
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

  clearTransactionFormAfterPost() {
    this.primaryAccountReferenceTarget.value = ""
    this.counterpartyAccountReferenceTarget.value = ""
    this.amountCentsTarget.value = "0"
    this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    this.approvalTokenTarget.value = ""
    this.checkRowsTarget.innerHTML = ""
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
    if (transactionType === "deposit") {
      return amountCents
    }

    if (["withdrawal", "check_cashing"].includes(transactionType)) {
      return -amountCents
    }

    return 0
  }

  generateRequestId() {
    return `ui-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  }

  transactionTypeLabel() {
    const transactionType = this.transactionTypeTarget.value || "transaction"
    return transactionType.charAt(0).toUpperCase() + transactionType.slice(1)
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

  generatedEntriesForCurrentState() {
    const transactionType = this.transactionTypeTarget.value
    const amountCents = this.effectiveAmountCents()
    const cashAmountCents = parseInt(this.amountCentsTarget.value || "0", 10)
    const { checkAmountCents, feeCents, netCashPayoutCents } = this.checkCashingAmounts()
    const checks = this.collectCheckRows()
    const primaryAccountReference = this.primaryAccountReferenceTarget.value.trim()
    const counterpartyAccountReference = this.counterpartyAccountReferenceTarget.value.trim()
    const cashAccountReference = this.cashAccountReferenceTarget.value.trim()
    const settlementAccountReference = this.hasSettlementAccountReferenceTarget ? this.settlementAccountReferenceTarget.value.trim() : ""
    const feeIncomeAccountReference = this.hasFeeIncomeAccountReferenceTarget ? this.feeIncomeAccountReferenceTarget.value.trim() : "income:check_cashing_fee"

    if (amountCents <= 0) {
      return []
    }

    if (transactionType === "deposit") {
      const entries = []

      if (cashAmountCents > 0) {
        entries.push({ side: "debit", account_reference: cashAccountReference, amount_cents: cashAmountCents })
      }

      checks
        .filter((check) => check.amount_cents > 0)
        .forEach((check, index) => {
          entries.push({
            side: "debit",
            account_reference: this.checkAccountReference(check, index),
            amount_cents: check.amount_cents
          })
        })

      entries.push({ side: "credit", account_reference: primaryAccountReference, amount_cents: amountCents })
      return entries
    }

    if (transactionType === "withdrawal") {
      return [
        { side: "debit", account_reference: primaryAccountReference, amount_cents: amountCents },
        { side: "credit", account_reference: cashAccountReference, amount_cents: amountCents }
      ]
    }

    if (transactionType === "transfer") {
      return [
        { side: "debit", account_reference: primaryAccountReference, amount_cents: amountCents },
        { side: "credit", account_reference: counterpartyAccountReference, amount_cents: amountCents }
      ]
    }

    if (transactionType === "check_cashing") {
      if (checkAmountCents <= 0 || netCashPayoutCents <= 0 || !settlementAccountReference) {
        return []
      }

      const entries = [
        { side: "debit", account_reference: settlementAccountReference, amount_cents: checkAmountCents },
        { side: "credit", account_reference: cashAccountReference, amount_cents: netCashPayoutCents }
      ]

      if (feeCents > 0) {
        entries.push({ side: "credit", account_reference: feeIncomeAccountReference, amount_cents: feeCents })
      }

      return entries
    }

    return []
  }

  appendEntries(formData) {
    const entries = this.generatedEntriesForCurrentState()
    entries.forEach((entry) => {
      formData.append("entries[][side]", entry.side)
      formData.append("entries[][account_reference]", entry.account_reference)
      formData.append("entries[][amount_cents]", entry.amount_cents.toString())
    })

    this.appendCheckItems(formData)
    this.appendCheckCashingPayload(formData)
  }

  appendCheckCashingPayload(formData) {
    if (this.transactionTypeTarget.value !== "check_cashing") {
      return
    }

    const amounts = this.checkCashingAmounts()
    formData.set("check_amount_cents", amounts.checkAmountCents.toString())
    formData.set("fee_cents", amounts.feeCents.toString())
    formData.set("settlement_account_reference", this.hasSettlementAccountReferenceTarget ? this.settlementAccountReferenceTarget.value.trim() : "")
    formData.set("fee_income_account_reference", this.hasFeeIncomeAccountReferenceTarget ? this.feeIncomeAccountReferenceTarget.value.trim() : "income:check_cashing_fee")
    formData.set("check_number", this.hasCheckNumberTarget ? this.checkNumberTarget.value.trim() : "")
    formData.set("routing_number", this.hasRoutingNumberTarget ? this.routingNumberTarget.value.trim() : "")
    formData.set("account_number", this.hasAccountNumberTarget ? this.accountNumberTarget.value.trim() : "")
    formData.set("payer_name", this.hasPayerNameTarget ? this.payerNameTarget.value.trim() : "")
    formData.set("presenter_type", this.hasPresenterTypeTarget ? this.presenterTypeTarget.value.trim() : "")
    formData.set("id_type", this.hasIdTypeTarget ? this.idTypeTarget.value.trim() : "")
    formData.set("id_number", this.hasIdNumberTarget ? this.idNumberTarget.value.trim() : "")
  }

  appendCheckItems(formData) {
    const checks = this.collectCheckRows()
    checks
      .filter((check) => check.amount_cents > 0)
      .forEach((check) => {
        formData.append("check_items[][routing]", check.routing)
        formData.append("check_items[][account]", check.account)
        formData.append("check_items[][number]", check.number)
        formData.append("check_items[][account_reference]", check.account_reference)
        formData.append("check_items[][amount_cents]", check.amount_cents.toString())
        formData.append("check_items[][hold_reason]", check.hold_reason || "")
        formData.append("check_items[][hold_until]", check.hold_until || "")
      })
  }

  effectiveAmountCents() {
    if (this.transactionTypeTarget.value === "check_cashing") {
      return this.checkCashingAmounts().netCashPayoutCents
    }

    const baseAmount = parseInt(this.amountCentsTarget.value || "0", 10)
    const depositCheckSubtotal = this.transactionTypeTarget.value === "deposit" ? this.checkSubtotalCents() : 0
    return Math.max(baseAmount, 0) + depositCheckSubtotal
  }

  checkCashingAmounts() {
    const checkAmountCents = this.hasCheckAmountCentsTarget ? Math.max(parseInt(this.checkAmountCentsTarget.value || "0", 10), 0) : 0
    const feeCents = this.hasFeeCentsTarget ? Math.max(parseInt(this.feeCentsTarget.value || "0", 10), 0) : 0

    return {
      checkAmountCents,
      feeCents,
      netCashPayoutCents: Math.max(checkAmountCents - feeCents, 0)
    }
  }

  hasInvalidCheckCashingFields({ checkAmountCents, feeCents, netCashPayoutCents }) {
    if (this.transactionTypeTarget.value !== "check_cashing") {
      return false
    }

    const hasSettlementAccount = this.hasSettlementAccountReferenceTarget && this.settlementAccountReferenceTarget.value.trim().length > 0
    const hasIdType = this.hasIdTypeTarget && this.idTypeTarget.value.trim().length > 0
    const hasIdNumber = this.hasIdNumberTarget && this.idNumberTarget.value.trim().length > 0

    return checkAmountCents <= 0 || feeCents < 0 || netCashPayoutCents <= 0 || !hasSettlementAccount || !hasIdType || !hasIdNumber
  }

  resetCheckCashingFields() {
    if (this.hasCheckAmountCentsTarget) {
      this.checkAmountCentsTarget.value = "0"
    }

    if (this.hasFeeCentsTarget) {
      this.feeCentsTarget.value = "0"
    }

    if (this.hasSettlementAccountReferenceTarget) {
      this.settlementAccountReferenceTarget.value = ""
    }

    if (this.hasCheckNumberTarget) {
      this.checkNumberTarget.value = ""
    }

    if (this.hasRoutingNumberTarget) {
      this.routingNumberTarget.value = ""
    }

    if (this.hasAccountNumberTarget) {
      this.accountNumberTarget.value = ""
    }

    if (this.hasPayerNameTarget) {
      this.payerNameTarget.value = ""
    }

    if (this.hasPresenterTypeTarget) {
      this.presenterTypeTarget.value = "customer"
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
    if (this.transactionTypeTarget.value !== "deposit") {
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

  showReceipt({ postingBatchId, tellerTransactionId, requestId, postedAt }) {
    if (!this.hasReceiptPanelTarget) {
      return
    }

    this.receiptBatchIdTarget.textContent = postingBatchId?.toString() || "N/A"
    this.receiptTransactionIdTarget.textContent = tellerTransactionId?.toString() || "N/A"
    this.receiptRequestIdTarget.textContent = requestId || "N/A"
    this.receiptPostedAtTarget.textContent = postedAt || "N/A"

    if (this.hasReceiptLinkTarget && this.hasReceiptUrlTemplateValue && requestId) {
      this.receiptLinkTarget.hidden = false
      this.receiptLinkTarget.href = this.receiptUrlTemplateValue.replace("__REQUEST_ID__", encodeURIComponent(requestId))
    }

    if (this.hasReceiptNewButtonTarget) {
      this.receiptNewButtonTarget.hidden = false
    }

    this.receiptPanelTarget.hidden = false

    if (this.hasReceiptNewButtonTarget) {
      this.receiptNewButtonTarget.focus()
    }
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
    if (firstField && typeof firstField.focus === "function") {
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
