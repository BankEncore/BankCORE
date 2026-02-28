import PostingFormBase from "services/posting_form_base"
import { buildEntries, computeTotals, calculateCashImpact } from "services/posting_balance"
import {
  getSections,
  getEntryProfile,
  hasSection as workflowHasSectionInConfig,
  blockedReason as workflowBlockedReason
} from "services/posting_workflows"

export default class extends PostingFormBase {
  static targets = [
    ...PostingFormBase.targets,
    "amountCents",
    "cashAmountRow",
    "cashAccountReference",
    "vaultTransferSection",
    "vaultTransferFromReference",
    "vaultTransferToReference",
    "vaultTransferReasonCode",
    "vaultTransferMemo",
    "computedCashSubtotal",
    "computedCheckSubtotal",
    "computedCashBackRow",
    "computedCashBackSubtotal",
    "computedFeeSubtotal",
    "computedNetTotal"
  ]

  connect() {
    super.connect()
  }

  getState() {
    const transactionType = "vault_transfer"
    const vaultTransferDetails = this.vaultTransferDetails()
    const amountCents = parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10)
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: "",
      counterpartyAccountReference: "",
      cashAccountReference: this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "",
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
      vaultTransferDetails,
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
    const transactionType = "vault_transfer"
    const state = this.getState()
    const schemaSections = getSections(transactionType, this.workflowSchema)
    const showVaultTransferSection = workflowHasSectionInConfig(transactionType, "vault_transfer", schemaSections)
    const vaultTransferDetails = state.vaultTransferDetails
    const totalAmountCents = state.effectiveAmountCents

    const hasVaultDirection = vaultTransferDetails.direction.length > 0
    const hasVaultReasonCode = vaultTransferDetails.reasonCode.length > 0
    const hasVaultMemo = vaultTransferDetails.reasonCode !== "other" || vaultTransferDetails.memo.length > 0
    const hasVaultEndpoints = vaultTransferDetails.valid
    const hasInvalidVaultTransferFields = this.hasInvalidVaultTransferFields(vaultTransferDetails)

    const entries = buildEntries(transactionType, state)
    const { debitTotal, creditTotal, imbalance, balanced } = computeTotals(entries)
    const displayedCashAmount = Math.max(state.amountCents, 0)
    const blockedReason = workflowBlockedReason({
      totalAmountCents,
      hasPrimaryAccount: false,
      requiresPrimaryAccount: false,
      requiresCounterparty: false,
      hasCounterparty: false,
      requiresCashAccount: false,
      hasCashAccount: false,
      requiresSettlementAccount: false,
      hasSettlementAccount: false,
      requiresParty: false,
      hasParty: false,
      requiresDraftDetails: false,
      hasDraftPayee: false,
      hasDraftInstrumentNumber: false,
      hasDraftLiabilityAccount: false,
      requiresVaultTransferDetails: showVaultTransferSection,
      hasVaultDirection,
      hasVaultReasonCode,
      hasVaultMemo,
      hasVaultEndpoints,
      hasInvalidCheckRows: false,
      hasInvalidCheckCashingFields: false,
      hasInvalidDraftFields: false,
      hasInvalidTransferFields: false,
      hasInvalidVaultTransferFields,
      balanced
    })

    if (this.hasVaultTransferSectionTarget) this.vaultTransferSectionTarget.hidden = !showVaultTransferSection
    this.setVaultTransferFieldState(showVaultTransferSection)

    if (this.hasComputedCashSubtotalTarget) this.computedCashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    if (this.hasComputedCheckSubtotalTarget) this.computedCheckSubtotalTarget.textContent = this.formatCents(0)
    if (this.hasComputedFeeSubtotalTarget) this.computedFeeSubtotalTarget.textContent = this.formatCents(0)
    if (this.hasComputedNetTotalTarget) this.computedNetTotalTarget.textContent = this.formatCents(totalAmountCents)

    if (this.hasStatusBadgeTarget) this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"

    const cashImpact = calculateCashImpact(transactionType, { amountCents: 0, vaultDirection: vaultTransferDetails.direction ?? "" }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || (showVaultTransferSection && (!hasVaultDirection || !hasVaultReasonCode || !hasVaultMemo || !hasVaultEndpoints)) || hasInvalidVaultTransferFields
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
        primaryReference: "",
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

  vaultTransferDetails() {
    const fromRef = this.hasVaultTransferFromReferenceTarget ? this.vaultTransferFromReferenceTarget.value.trim() : ""
    const toRef = this.hasVaultTransferToReferenceTarget ? this.vaultTransferToReferenceTarget.value.trim() : ""
    const drawerRef = (this.hasDrawerReferenceValue && this.drawerReferenceValue) ? this.drawerReferenceValue.trim() : (this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value.trim() : "")
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
    if (!["drawer_to_vault", "vault_to_drawer", "vault_to_vault"].includes(details.direction)) {
      return true
    }
    if (!details.reasonCode) return true
    if (details.reasonCode === "other" && !details.memo) return true
    return !details.valid
  }

  setVaultTransferFieldState(enabled) {
    if (!this.hasVaultTransferSectionTarget) return

    this.vaultTransferSectionTarget
      .querySelectorAll("input, select, textarea")
      .forEach((field) => { field.disabled = !enabled })

    if (!enabled) return
    if (this.hasVaultTransferMemoTarget && this.hasVaultTransferReasonCodeTarget) {
      const reasonCode = this.vaultTransferReasonCodeTarget.value.trim()
      const memoRequired = reasonCode === "other"
      this.vaultTransferMemoTarget.required = memoRequired
      this.vaultTransferMemoTarget.setAttribute("aria-required", memoRequired ? "true" : "false")
    }
  }

  effectiveAmountCents() {
    const baseAmount = parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10)
    return Math.max(baseAmount, 0)
  }

  resetFormFieldClearing(_isAfterPost = false) {
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (this.hasVaultTransferFromReferenceTarget) this.vaultTransferFromReferenceTarget.value = ""
    if (this.hasVaultTransferToReferenceTarget) this.vaultTransferToReferenceTarget.value = ""
    if (this.hasVaultTransferReasonCodeTarget) this.vaultTransferReasonCodeTarget.value = ""
    if (this.hasVaultTransferMemoTarget) this.vaultTransferMemoTarget.value = ""
  }

  focusFirstField() {
    const firstField = (this.hasAmountCentsTarget ? this.amountCentsTarget : null) || (this.hasVaultTransferFromReferenceTarget ? this.vaultTransferFromReferenceTarget : null)
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
