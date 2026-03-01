import PostingFormBase from "services/posting_form_base"
import { buildEntries, computeTotals, calculateCashImpact } from "services/posting_balance"
import {
  getSections,
  getEntryProfile,
  getRequiresPrimaryAccount,
  getRequiresCashAccount,
  getRequiresParty,
  hasSection as workflowHasSectionInConfig,
  blockedReason as workflowBlockedReason
} from "services/posting_workflows"

export default class extends PostingFormBase {
  static targets = [
    ...PostingFormBase.targets,
    "primaryAccountReference",
    "primaryAccountRow",
    "cashAccountReference",
    "amountCents",
    "payeeSelect",
    "payeeReference",
    "paymentCents",
    "feeCents",
    "liabilityAccountReference",
    "totalDueDisplay",
    "memoRow",
    "memo",
    "checkSection",
    "checkRows",
    "checkTemplate",
    "billPaymentSection",
    "billPaymentCashCents",
    "billPaymentAccountCents",
    "cashCountModalWrapper",
    "checkSubtotal",
    "totalDueAmount",
    "balance",
    "partyId"
  ]

  connect() {
    this.defaultCashAccountReference = this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : ""
    super.connect()
  }

  onPayeeChange(event) {
    const option = event.target.selectedOptions?.[0]
    if (option) {
      const liabilityRef = option.dataset?.liabilityRef ?? ""
      const defaultFeeCents = option.dataset?.defaultFeeCents ?? ""
      const memoRequired = option.dataset?.memoRequired === "1"
      if (this.hasLiabilityAccountReferenceTarget) this.liabilityAccountReferenceTarget.value = liabilityRef
      if (this.hasMemoTarget) {
        this.memoTarget.required = memoRequired
        this.memoTarget.setAttribute("aria-required", memoRequired ? "true" : "false")
      }
      if (defaultFeeCents && this.hasFeeCentsTarget) {
        const currentCents = parseInt(this.feeCentsTarget.value || "0", 10)
        if (currentCents === 0) {
          this.setAmountCents(this.feeCentsTarget, parseInt(defaultFeeCents, 10))
          const wrapper = this.feeCentsTarget.closest?.("[data-controller~=\"currency-input\"]")
          const displayInput = wrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
          if (displayInput) {
            const dollars = parseInt(defaultFeeCents, 10) / 100
            displayInput.value = dollars.toFixed(2)
          }
        }
      }
    }
    this.recalculate()
  }

  getState() {
    const transactionType = "bill_payment"
    const billPaymentAmounts = this.billPaymentAmounts()
    const memoRequired = this.getMemoRequiredFromSelectedPayee()
    const checks = this.collectCheckRows()
    const effectiveAmountCents = billPaymentAmounts.totalDueCents ?? 0
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget.value : "",
      counterpartyAccountReference: "",
      cashAccountReference: this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "",
      amountCents: effectiveAmountCents,
      cashBackCents: 0,
      effectiveAmountCents,
      checks,
      checkCashingAmounts: { checkAmountCents: 0, feeCents: 0, netCashPayoutCents: 0 },
      settlementAccountReference: "",
      feeIncomeAccountReference: "income:bill_payment_fee",
      draftAmounts: {},
      draftLiabilityAccountReference: "",
      draftFeeIncomeAccountReference: "",
      draftPayeeName: "",
      draftInstrumentNumber: "",
      transferAmounts: { feeCents: 0 },
      transferFeeIncomeAccountReference: "income:transfer_fee",
      vaultTransferDetails: {},
      drawerReference: (this.hasDrawerReferenceValue && this.drawerReferenceValue) ? this.drawerReferenceValue : (this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : ""),
      checkNumber: "",
      routingNumber: "",
      accountNumber: "",
      payerName: "",
      presenterType: "",
      partyId: this.hasPartyIdTarget ? this.partyIdTarget.value : "",
      billPaymentAmounts,
      memoRequired,
      payeeId: this.hasPayeeSelectTarget ? this.payeeSelectTarget.value : "",
      payeeReference: this.hasPayeeReferenceTarget ? this.payeeReferenceTarget.value : "",
      liabilityAccountReference: this.hasLiabilityAccountReferenceTarget ? this.liabilityAccountReferenceTarget.value : "",
      memo: this.hasMemoTarget ? this.memoTarget.value : "",
      denominationLines: this.denominationLines || []
    }
  }

  onDenominationChange(event) {
    const { totalCents = 0, lines = [] } = event.detail || {}
    this.denominationLines = lines
    if (this.hasBillPaymentCashCentsTarget) {
      this.setAmountCents(this.billPaymentCashCentsTarget, totalCents)
    }
    if (typeof this.recalculate === "function") this.recalculate()
  }

  recalculate() {
    const transactionType = "bill_payment"
    const state = this.getState()
    const schemaSections = getSections(transactionType, this.workflowSchema)
    const showBillPaymentSection = workflowHasSectionInConfig(transactionType, "bill_payment", schemaSections)
    const showCheckSection = workflowHasSectionInConfig(transactionType, "checks", schemaSections)
    const billPaymentAmounts = state.billPaymentAmounts

    if (this.hasAmountCentsTarget) {
      this.setAmountCents(this.amountCentsTarget, billPaymentAmounts.totalDueCents ?? 0)
    }
    if (this.hasTotalDueDisplayTarget) {
      this.totalDueDisplayTarget.textContent = this.formatCents(billPaymentAmounts.totalDueCents ?? 0)
    }
    const memoRequired = state.memoRequired ?? false
    if (this.hasMemoTarget) {
      this.memoTarget.required = memoRequired
      this.memoTarget.setAttribute("aria-required", memoRequired ? "true" : "false")
    }
    if (this.hasMemoRowTarget) {
      const lbl = this.memoRowTarget.querySelector("label")
      if (lbl) lbl.textContent = memoRequired ? "Memo" : "Memo (optional)"
    }
    if (this.hasCashCountModalWrapperTarget) {
      const cashCents = billPaymentAmounts.billPaymentCashCents ?? 0
      this.cashCountModalWrapperTarget.dataset.expectedCents = String(cashCents)
    }

    const totalAmountCents = state.effectiveAmountCents
    const workflowContext = {
      billPaymentAccountCents: billPaymentAmounts.billPaymentAccountCents ?? 0,
      billPaymentCashCents: billPaymentAmounts.billPaymentCashCents ?? 0
    }
    const hasPrimaryAccount = state.primaryAccountReference.trim().length > 0
    const requiresPrimaryAccount = getRequiresPrimaryAccount(transactionType, this.workflowSchema, workflowContext)
    const requiresCashAccount = getRequiresCashAccount(transactionType, this.workflowSchema, workflowContext)
    const requiresParty = getRequiresParty(transactionType, this.workflowSchema)
    const hasServedParty = state.partyId.trim().length > 0
    const hasCashAccount = state.cashAccountReference.trim().length > 0
    const hasPayee = (state.payeeId ?? "").trim().length > 0
    const hasPayeeReference = (state.payeeReference ?? "").trim().length > 0
    const hasLiabilityRef = (state.liabilityAccountReference ?? "").trim().length > 0
    const hasMemo = state.memo.trim().length > 0
    const hasInvalidCheckRows = this.hasInvalidCheckRows()
    const hasInvalidBillPaymentFields = this.hasInvalidBillPaymentFields(billPaymentAmounts, state)

    const entries = buildEntries(transactionType, state)
    const { debitTotal, creditTotal, imbalance, balanced } = computeTotals(entries)
    const blockedReason = workflowBlockedReason({
      totalAmountCents,
      hasPrimaryAccount,
      requiresPrimaryAccount,
      requiresCounterparty: false,
      hasCounterparty: false,
      requiresCashAccount,
      hasCashAccount,
      requiresSettlementAccount: false,
      hasSettlementAccount: false,
      requiresParty,
      hasParty: hasServedParty,
      requiresDraftDetails: false,
      hasDraftPayee: true,
      hasDraftInstrumentNumber: true,
      hasDraftLiabilityAccount: true,
      requiresVaultTransferDetails: false,
      hasVaultDirection: false,
      hasVaultReasonCode: false,
      hasVaultMemo: false,
      hasVaultEndpoints: false,
      hasInvalidCheckRows,
      hasInvalidCheckCashingFields: false,
      hasInvalidDraftFields: false,
      hasInvalidMiscReceiptFields: false,
      hasInvalidBillPaymentFields,
      hasInvalidTransferFields: false,
      hasInvalidVaultTransferFields: false,
      balanced
    })

    if (this.hasCheckSectionTarget) this.checkSectionTarget.hidden = !showCheckSection
    if (this.hasBillPaymentSectionTarget) this.billPaymentSectionTarget.hidden = !showBillPaymentSection
    if (this.hasPrimaryAccountReferenceTarget) {
      this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
      this.primaryAccountReferenceTarget.setAttribute("aria-required", requiresPrimaryAccount ? "true" : "false")
    }

    if (this.hasCheckSubtotalTarget) this.checkSubtotalTarget.textContent = this.formatCents(billPaymentAmounts.checkCents ?? 0)
    if (this.hasTotalDueAmountTarget) this.totalDueAmountTarget.textContent = `Total due: ${this.formatCents(billPaymentAmounts.totalDueCents ?? 0)}`
    if (this.hasBalanceTarget) {
      const balance = billPaymentAmounts.balanceCents ?? 0
      this.balanceTarget.textContent = `Balance: ${this.formatCents(balance)}`
      this.balanceTarget.classList.toggle("text-error", balance !== 0)
    }

    if (this.hasStatusBadgeTarget) this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"

    const cashImpact = calculateCashImpact(transactionType, { billPaymentCashCents: billPaymentAmounts.billPaymentCashCents ?? 0 }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || !hasPayee || !hasPayeeReference || !hasLiabilityRef || (memoRequired && !hasMemo) || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCashAccount && !hasCashAccount) || (requiresParty && !hasServedParty) || hasInvalidCheckRows || hasInvalidBillPaymentFields
    let disabled = blockedReason.length > 0 || !balanced || hasMissingFields
    if (this.postedLocked) disabled = true

    this.submitButtonTarget.disabled = disabled
    if (this.hasHeaderSubmitButtonTarget) this.headerSubmitButtonTarget.disabled = disabled

    if (balanced) this.setHeaderState("Balanced")
    else this.setHeaderState("Editing")

    if (this.hasPostingPreviewBodyTarget) this.renderPostingPreview(entries)
    if (this.hasAvailabilitySectionTarget) this.availabilitySectionTarget.hidden = true

    this.element.dispatchEvent(new CustomEvent("tx:recalc", {
      bubbles: true,
      detail: {
        transactionType,
        entries,
        primaryReference: (this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget.value : "").trim(),
        counterpartyReference: "",
        cashReference: (this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "").trim(),
        partyId: (this.hasPartyIdTarget ? this.partyIdTarget.value : "").trim(),
        requestId: this.requestIdInput()?.value,
        cashAmountCents: billPaymentAmounts.billPaymentCashCents ?? 0,
        checkAmountCents: 0,
        feeCents: billPaymentAmounts.feeCents ?? 0,
        draftAmountCents: 0,
        draftFeeCents: 0,
        checkSubtotalCents: billPaymentAmounts.checkCents ?? 0,
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

  billPaymentAmounts() {
    const paymentCents = this.hasPaymentCentsTarget ? Math.max(parseInt(this.paymentCentsTarget.value || "0", 10), 0) : 0
    const feeCents = this.hasFeeCentsTarget ? Math.max(parseInt(this.feeCentsTarget.value || "0", 10), 0) : 0
    const totalDueCents = paymentCents + feeCents
    const billPaymentCashCents = this.hasBillPaymentCashCentsTarget ? Math.max(parseInt(this.billPaymentCashCentsTarget.value || "0", 10), 0) : 0
    const billPaymentAccountCents = this.hasBillPaymentAccountCentsTarget ? Math.max(parseInt(this.billPaymentAccountCentsTarget.value || "0", 10), 0) : 0
    const checkCents = this.checkSubtotalCents()

    return {
      paymentCents,
      feeCents,
      totalDueCents,
      billPaymentCashCents,
      billPaymentAccountCents,
      checkCents,
      totalPaymentCents: billPaymentCashCents + billPaymentAccountCents + checkCents,
      balanceCents: totalDueCents - (billPaymentCashCents + billPaymentAccountCents + checkCents)
    }
  }

  getMemoRequiredFromSelectedPayee() {
    if (!this.hasPayeeSelectTarget) return false
    const option = this.payeeSelectTarget.selectedOptions?.[0]
    return option?.dataset?.memoRequired === "1"
  }

  checkSubtotalCents() {
    return this.collectCheckRows().reduce((sum, check) => sum + (check.amount_cents ?? 0), 0)
  }

  collectCheckRows() {
    if (!this.hasCheckRowsTarget) return []
    return Array.from(this.checkRowsTarget.querySelectorAll("[data-check-row]")).map((row, index) => {
      const routing = row.querySelector('[data-check-field="routing"]')?.value?.trim() || ""
      const account = row.querySelector('[data-check-field="account"]')?.value?.trim() || ""
      const number = row.querySelector('[data-check-field="number"]')?.value?.trim() || ""
      const amountCents = parseInt(row.querySelector('[data-check-field="amount"]')?.value || "0", 10)
      const checkType = row.querySelector('[data-check-field="checkType"]')?.value?.trim() || "transit"
      const holdReason = row.querySelector('[data-check-field="holdReason"]')?.value?.trim() || ""
      const holdUntil = row.querySelector('[data-check-field="holdUntil"]')?.value?.trim() || ""

      return {
        routing,
        account,
        number,
        account_reference: this.checkAccountReference({ routing, account, number }, index),
        amount_cents: amountCents > 0 ? amountCents : 0,
        check_type: checkType,
        hold_reason: holdReason,
        hold_until: holdUntil
      }
    })
  }

  hasInvalidCheckRows() {
    return this.collectCheckRows().some((check) => {
      if (check.amount_cents <= 0) return false
      return [check.routing, check.account, check.number].some((field) => field.length === 0)
    })
  }

  hasInvalidBillPaymentFields(billPaymentAmounts, state) {
    const { paymentCents = 0, totalDueCents = 0, balanceCents = 0 } = billPaymentAmounts
    const hasPayee = (state.payeeId ?? "").trim().length > 0
    const hasPayeeReference = (state.payeeReference ?? "").trim().length > 0
    const hasLiabilityRef = (state.liabilityAccountReference ?? "").trim().length > 0
    const memoRequired = state.memoRequired ?? false
    const hasMemo = (state.memo ?? "").trim().length > 0
    return paymentCents <= 0 || !hasPayee || !hasPayeeReference || !hasLiabilityRef || balanceCents !== 0 || (memoRequired && !hasMemo)
  }

  checkAccountReference(check, index) {
    const routing = check.routing || "unknown-routing"
    const account = check.account || "unknown-account"
    const number = check.number || `unknown-${index + 1}`
    return `check:${routing}:${account}:${number}`
  }

  effectiveAmountCents() {
    return this.billPaymentAmounts().totalDueCents ?? 0
  }

  resetFormFieldClearing(isAfterPost = false) {
    if (this.hasPrimaryAccountReferenceTarget) this.primaryAccountReferenceTarget.value = ""
    if (this.hasPartyIdTarget) this.partyIdTarget.value = ""
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (this.hasPaymentCentsTarget) this.setAmountCents(this.paymentCentsTarget, 0)
    if (this.hasFeeCentsTarget) this.setAmountCents(this.feeCentsTarget, 0)
    this.denominationLines = []
    if (this.hasBillPaymentCashCentsTarget) this.setAmountCents(this.billPaymentCashCentsTarget, 0)
    if (this.hasBillPaymentAccountCentsTarget) this.setAmountCents(this.billPaymentAccountCentsTarget, 0)
    if (this.hasMemoTarget) {
      this.memoTarget.value = ""
      this.memoTarget.required = false
    }
    if (this.hasPayeeSelectTarget) this.payeeSelectTarget.value = ""
    if (this.hasPayeeReferenceTarget) this.payeeReferenceTarget.value = ""
    if (this.hasLiabilityAccountReferenceTarget) this.liabilityAccountReferenceTarget.value = ""
    if (this.hasCheckRowsTarget) this.checkRowsTarget.innerHTML = ""
    const paymentWrapper = this.paymentCentsTarget?.closest?.("[data-controller~=\"currency-input\"]")
    const paymentDisplayInput = paymentWrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
    if (paymentDisplayInput) paymentDisplayInput.value = ""
    const feeWrapper = this.feeCentsTarget?.closest?.("[data-controller~=\"currency-input\"]")
    const feeDisplayInput = feeWrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
    if (feeDisplayInput) feeDisplayInput.value = ""
    if (isAfterPost && this.hasCashAccountReferenceTarget) {
      this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    }
  }

  focusFirstField() {
    const firstField = this.hasPayeeSelectTarget ? this.payeeSelectTarget : (this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget : null)
    if (firstField && typeof firstField.focus === "function") firstField.focus()
  }
}
