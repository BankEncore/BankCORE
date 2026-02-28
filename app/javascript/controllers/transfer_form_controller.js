import PostingFormBase from "services/posting_form_base"
import { buildEntries, computeTotals, calculateCashImpact } from "services/posting_balance"
import {
  getSections,
  getEntryProfile,
  getRequiresPrimaryAccount,
  getRequiresCounterpartyAccount,
  getRequiresCashAccount,
  hasSection as workflowHasSectionInConfig,
  blockedReason as workflowBlockedReason
} from "services/posting_workflows"

export default class extends PostingFormBase {
  static targets = [
    ...PostingFormBase.targets,
    "primaryAccountReference",
    "primaryAccountRow",
    "counterpartyAccountReference",
    "counterpartyRow",
    "cashAccountReference",
    "amountCents",
    "cashAmountRow",
    "transferSection",
    "transferFeeCents",
    "transferFeeIncomeAccountReference",
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
    const transactionType = "transfer"
    const transferAmounts = this.transferAmounts()
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)
    const amountCents = parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10)
    const totalAmountCents = Math.max(amountCents, 0)

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget.value : "",
      counterpartyAccountReference: this.hasCounterpartyAccountReferenceTarget ? this.counterpartyAccountReferenceTarget.value : "",
      cashAccountReference: this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "",
      amountCents,
      cashBackCents: 0,
      effectiveAmountCents: totalAmountCents,
      checks: [],
      checkCashingAmounts: { checkAmountCents: 0, feeCents: 0, netCashPayoutCents: 0 },
      settlementAccountReference: "",
      feeIncomeAccountReference: "income:check_cashing_fee",
      draftAmounts: {},
      draftLiabilityAccountReference: "official_check:outstanding",
      draftFeeIncomeAccountReference: "income:draft_fee",
      draftPayeeName: "",
      draftInstrumentNumber: "",
      transferAmounts,
      transferFeeIncomeAccountReference: this.hasTransferFeeIncomeAccountReferenceTarget ? this.transferFeeIncomeAccountReferenceTarget.value : "income:transfer_fee",
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
    const transactionType = "transfer"
    const state = this.getState()
    const schemaSections = getSections(transactionType, this.workflowSchema)
    const showTransferSection = workflowHasSectionInConfig(transactionType, "transfer", schemaSections)
    const transferAmounts = state.transferAmounts
    const totalAmountCents = state.effectiveAmountCents

    const hasPrimaryAccount = state.primaryAccountReference.trim().length > 0
    const hasCounterparty = state.counterpartyAccountReference.trim().length > 0
    const requiresPrimaryAccount = getRequiresPrimaryAccount(transactionType, this.workflowSchema, {})
    const requiresCounterparty = getRequiresCounterpartyAccount(transactionType, this.workflowSchema)
    const requiresCashAccount = getRequiresCashAccount(transactionType, this.workflowSchema, {})
    const hasCashAccount = state.cashAccountReference.trim().length > 0
    const hasInvalidTransferFields = this.hasInvalidTransferFields(transferAmounts, totalAmountCents, showTransferSection)

    const entries = buildEntries(transactionType, state)
    const { debitTotal, creditTotal, imbalance, balanced } = computeTotals(entries)
    const displayedCashAmount = Math.max(state.amountCents, 0)
    const blockedReason = workflowBlockedReason({
      totalAmountCents,
      hasPrimaryAccount,
      requiresPrimaryAccount,
      requiresCounterparty,
      hasCounterparty,
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
      hasInvalidTransferFields,
      hasInvalidVaultTransferFields: false,
      balanced
    })

    if (this.hasCounterpartyRowTarget) this.counterpartyRowTarget.hidden = !requiresCounterparty
    if (this.hasTransferSectionTarget) this.transferSectionTarget.hidden = !showTransferSection
    if (this.hasPrimaryAccountReferenceTarget) {
      this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
      this.primaryAccountReferenceTarget.setAttribute("aria-required", requiresPrimaryAccount ? "true" : "false")
    }

    if (this.hasComputedCashSubtotalTarget) this.computedCashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    if (this.hasComputedCheckSubtotalTarget) this.computedCheckSubtotalTarget.textContent = this.formatCents(0)
    if (this.hasComputedFeeSubtotalTarget) {
      const feeCents = showTransferSection ? (transferAmounts.feeCents ?? 0) : 0
      this.computedFeeSubtotalTarget.textContent = feeCents > 0 ? `-${this.formatCents(feeCents)}` : this.formatCents(0)
    }
    if (this.hasComputedNetTotalTarget) this.computedNetTotalTarget.textContent = this.formatCents(totalAmountCents)

    if (this.hasStatusBadgeTarget) this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"

    const cashImpact = calculateCashImpact(transactionType, { amountCents: displayedCashAmount }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCounterparty && !hasCounterparty) || (requiresCashAccount && !hasCashAccount) || hasInvalidTransferFields
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
        counterpartyReference: (this.hasCounterpartyAccountReferenceTarget ? this.counterpartyAccountReferenceTarget.value : "").trim(),
        cashReference: (this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "").trim(),
        partyId: "",
        requestId: this.requestIdInput()?.value,
        cashAmountCents: displayedCashAmount,
        checkAmountCents: 0,
        feeCents: transferAmounts.feeCents ?? 0,
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

  transferAmounts() {
    const feeCents = this.hasTransferFeeCentsTarget ? Math.max(parseInt(this.transferFeeCentsTarget.value || "0", 10), 0) : 0
    return { feeCents }
  }

  hasInvalidTransferFields(transferAmounts, totalAmountCents, showTransferSection) {
    if (!showTransferSection) return false
    const feeCents = transferAmounts?.feeCents ?? 0
    return feeCents < 0 || feeCents > totalAmountCents
  }

  effectiveAmountCents() {
    const baseAmount = parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10)
    return Math.max(baseAmount, 0)
  }

  resetFormFieldClearing(isAfterPost = false) {
    if (this.hasPrimaryAccountReferenceTarget) this.primaryAccountReferenceTarget.value = ""
    if (this.hasCounterpartyAccountReferenceTarget) this.counterpartyAccountReferenceTarget.value = ""
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (this.hasTransferFeeCentsTarget) this.setAmountCents(this.transferFeeCentsTarget, 0)
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
