import PostingFormBase from "services/posting_form_base"
import { buildEntries, computeTotals, calculateCashImpact } from "services/posting_balance"
import {
  getEntryProfile,
  getRequiresPrimaryAccount,
  getRequiresCashAccount,
  blockedReason as workflowBlockedReason
} from "services/posting_workflows"

export default class extends PostingFormBase {
  static targets = [
    ...PostingFormBase.targets,
    "primaryAccountReference",
    "primaryAccountRow",
    "cashAccountReference",
    "amountCents",
    "cashAmountRow",
    "computedCashSubtotal",
    "computedCheckSubtotal",
    "computedCashBackRow",
    "computedCashBackSubtotal",
    "computedFeeSubtotal",
    "computedNetTotal"
  ]

  connect() {
    this.defaultCashAccountReference = this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : ""
    super.connect()
  }

  getState() {
    const transactionType = "withdrawal"
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)
    const amountCents = parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10)

    const rawCashRef = (this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "").trim()
    const drawerRef = (this.hasDrawerReferenceValue && this.drawerReferenceValue ? this.drawerReferenceValue : "").trim()
    const cashAccountReference = rawCashRef || drawerRef
    if (cashAccountReference && this.hasCashAccountReferenceTarget && !rawCashRef) {
      this.cashAccountReferenceTarget.value = cashAccountReference
    }

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget.value : "",
      counterpartyAccountReference: "",
      cashAccountReference,
      amountCents,
      cashBackCents: 0,
      effectiveAmountCents: Math.max(amountCents, 0),
      checks: [],
      checkCashingAmounts: { checkAmountCents: 0, feeCents: 0, netCashPayoutCents: 0 },
      settlementAccountReference: "",
      feeIncomeAccountReference: "income:check_cashing_fee",
      draftAmounts: {},
      draftLiabilityAccountReference: "official_check:outstanding",
      draftFeeIncomeAccountReference: "income:draft_fee",
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
      idType: "",
      idNumber: "",
      partyId: ""
    }
  }

  recalculate() {
    const transactionType = "withdrawal"
    const state = this.getState()
    const totalAmountCents = state.effectiveAmountCents
    const hasPrimaryAccount = state.primaryAccountReference.trim().length > 0
    const requiresPrimaryAccount = getRequiresPrimaryAccount(transactionType, this.workflowSchema, {})
    const requiresCashAccount = getRequiresCashAccount(transactionType, this.workflowSchema, {})
    const hasCashAccount = state.cashAccountReference.trim().length > 0

    const entries = buildEntries(transactionType, state)
    const { debitTotal, creditTotal, imbalance, balanced } = computeTotals(entries)
    const displayedCashAmount = Math.max(state.amountCents, 0)
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
      requiresParty: false,
      hasParty: false,
      requiresDraftDetails: false,
      hasDraftPayee: false,
      hasDraftInstrumentNumber: false,
      hasDraftLiabilityAccount: false,
      requiresVaultTransferDetails: false,
      hasVaultDirection: false,
      hasVaultReasonCode: false,
      hasVaultMemo: false,
      hasVaultEndpoints: false,
      hasInvalidCheckRows: false,
      hasInvalidCheckCashingFields: false,
      hasInvalidDraftFields: false,
      hasInvalidTransferFields: false,
      hasInvalidVaultTransferFields: false,
      balanced
    })

    if (this.hasPrimaryAccountReferenceTarget) {
      this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
      this.primaryAccountReferenceTarget.setAttribute("aria-required", requiresPrimaryAccount ? "true" : "false")
    }

    if (this.hasComputedCashSubtotalTarget) this.computedCashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    if (this.hasComputedCheckSubtotalTarget) this.computedCheckSubtotalTarget.textContent = this.formatCents(0)
    if (this.hasComputedFeeSubtotalTarget) this.computedFeeSubtotalTarget.textContent = this.formatCents(0)
    if (this.hasComputedNetTotalTarget) this.computedNetTotalTarget.textContent = this.formatCents(totalAmountCents)

    if (this.hasStatusBadgeTarget) this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"

    const cashImpact = calculateCashImpact(transactionType, { amountCents: displayedCashAmount }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCashAccount && !hasCashAccount)
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
        partyId: "",
        requestId: this.requestIdInput()?.value,
        cashAmountCents: displayedCashAmount,
        checkAmountCents: 0,
        feeCents: 0,
        draftAmountCents: 0,
        draftFeeCents: 0,
        checkSubtotalCents: 0,
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

  effectiveAmountCents() {
    const baseAmount = parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10)
    return Math.max(baseAmount, 0)
  }

  resetFormFieldClearing(isAfterPost = false) {
    if (this.hasPrimaryAccountReferenceTarget) this.primaryAccountReferenceTarget.value = ""
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (isAfterPost && this.hasCashAccountReferenceTarget) {
      this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    }
  }

  focusFirstField() {
    const firstField = (this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget : null) || (this.hasAmountCentsTarget ? this.amountCentsTarget : null)
    if (!firstField || typeof firstField.focus !== "function") return
    const wrapper = firstField.closest?.("[data-controller~=\"currency-input\"]")
    const displayInput = wrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
    if (displayInput && typeof displayInput.focus === "function") {
      displayInput.focus()
    } else {
      firstField.focus()
    }
  }
}
