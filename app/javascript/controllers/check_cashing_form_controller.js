import PostingFormBase from "services/posting_form_base"
import { buildEntries, computeTotals, calculateCashImpact } from "services/posting_balance"
import {
  getSections,
  getEntryProfile,
  getRequiresParty,
  hasSection as workflowHasSectionInConfig,
  blockedReason as workflowBlockedReason
} from "services/posting_workflows"

export default class extends PostingFormBase {
  static targets = [
    ...PostingFormBase.targets,
    "amountCents",
    "cashAccountReference",
    "checkSection",
    "checkRows",
    "checkTemplate",
    "checkCashingSection",
    "checkCashingIdRow",
    "partyId",
    "feeCents",
    "feeIncomeAccountReference",
    "idType",
    "idNumber",
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
    const transactionType = "check_cashing"
    const checkCashingAmounts = this.checkCashingAmounts()
    const checks = this.collectCheckRows()
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: "",
      counterpartyAccountReference: "",
      cashAccountReference: this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "",
      amountCents: checkCashingAmounts.netCashPayoutCents,
      cashBackCents: 0,
      effectiveAmountCents: checkCashingAmounts.netCashPayoutCents,
      checks,
      checkCashingAmounts,
      settlementAccountReference: "",
      feeIncomeAccountReference: this.hasFeeIncomeAccountReferenceTarget ? this.feeIncomeAccountReferenceTarget.value : "income:check_cashing_fee",
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
      idType: this.hasIdTypeTarget ? this.idTypeTarget.value : "",
      idNumber: this.hasIdNumberTarget ? this.idNumberTarget.value : "",
      partyId: this.hasPartyIdTarget ? this.partyIdTarget.value : ""
    }
  }

  recalculate() {
    const transactionType = "check_cashing"
    const state = this.getState()
    const schemaSections = getSections(transactionType, this.workflowSchema)
    const showCheckSection = workflowHasSectionInConfig(transactionType, "checks", schemaSections)
    const showCheckCashingSection = true
    const checkCashingAmounts = state.checkCashingAmounts

    if (this.hasAmountCentsTarget) {
      this.setAmountCents(this.amountCentsTarget, checkCashingAmounts.netCashPayoutCents)
    }

    const totalAmountCents = state.effectiveAmountCents
    const hasParty = state.partyId.trim().length > 0
    const requiresParty = getRequiresParty(transactionType, this.workflowSchema)
    const hasInvalidCheckRows = this.hasInvalidCheckRows()
    const hasInvalidCheckCashingFields = this.hasInvalidCheckCashingFields(checkCashingAmounts)

    const entries = buildEntries(transactionType, state)
    const { debitTotal, creditTotal, imbalance, balanced } = computeTotals(entries)
    const checkSubtotalCents = this.checkSubtotalCents()
    const displayedCashAmount = checkCashingAmounts.netCashPayoutCents
    const blockedReason = workflowBlockedReason({
      totalAmountCents,
      hasPrimaryAccount: false,
      requiresPrimaryAccount: false,
      requiresCounterparty: false,
      hasCounterparty: false,
      requiresCashAccount: true,
      hasCashAccount: state.cashAccountReference.trim().length > 0,
      requiresSettlementAccount: false,
      hasSettlementAccount: false,
      requiresParty,
      hasParty,
      requiresDraftDetails: false,
      hasDraftPayee: false,
      hasDraftInstrumentNumber: false,
      hasDraftLiabilityAccount: false,
      requiresVaultTransferDetails: false,
      hasVaultDirection: false,
      hasVaultReasonCode: false,
      hasVaultMemo: false,
      hasVaultEndpoints: false,
      hasInvalidCheckRows,
      hasInvalidCheckCashingFields,
      hasInvalidDraftFields: false,
      hasInvalidTransferFields: false,
      hasInvalidVaultTransferFields: false,
      balanced
    })

    if (this.hasCheckSectionTarget) this.checkSectionTarget.hidden = !showCheckSection
    if (this.hasCheckCashingSectionTarget) this.checkCashingSectionTarget.hidden = !showCheckCashingSection
    if (this.hasCheckCashingIdRowTarget) this.checkCashingIdRowTarget.hidden = !showCheckCashingSection
    if (this.hasIdNumberTarget) {
      const idRequired = showCheckCashingSection && !hasParty
      this.idNumberTarget.required = idRequired
      this.idNumberTarget.setAttribute("aria-required", idRequired ? "true" : "false")
    }

    if (this.hasComputedCashSubtotalTarget) this.computedCashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    if (this.hasComputedCheckSubtotalTarget) this.computedCheckSubtotalTarget.textContent = this.formatCents(checkSubtotalCents)
    if (this.hasComputedFeeSubtotalTarget) {
      const feeCents = checkCashingAmounts.feeCents ?? 0
      this.computedFeeSubtotalTarget.textContent = feeCents > 0 ? `-${this.formatCents(feeCents)}` : this.formatCents(0)
    }
    if (this.hasComputedNetTotalTarget) this.computedNetTotalTarget.textContent = this.formatCents(totalAmountCents)

    if (this.hasStatusBadgeTarget) this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"

    const cashImpact = calculateCashImpact(transactionType, { amountCents: displayedCashAmount }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || (requiresParty && !hasParty) || hasInvalidCheckRows || hasInvalidCheckCashingFields
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
        partyId: this.hasPartyIdTarget ? this.partyIdTarget.value.trim() : "",
        requestId: this.requestIdInput()?.value,
        cashAmountCents: displayedCashAmount,
        checkAmountCents: checkCashingAmounts.checkAmountCents,
        feeCents: checkCashingAmounts.feeCents,
        draftAmountCents: 0,
        draftFeeCents: 0,
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

  checkCashingAmounts() {
    const checkSubtotalCents = this.checkSubtotalCents()
    const feeCents = this.hasFeeCentsTarget ? Math.max(parseInt(this.feeCentsTarget.value || "0", 10), 0) : 0
    return {
      checkAmountCents: checkSubtotalCents,
      feeCents,
      netCashPayoutCents: Math.max(checkSubtotalCents - feeCents, 0)
    }
  }

  checkSubtotalCents() {
    return this.collectCheckRows().reduce((sum, check) => sum + check.amount_cents, 0)
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

  hasInvalidCheckCashingFields({ checkAmountCents, feeCents, netCashPayoutCents }) {
    const hasParty = this.hasPartyIdTarget && this.partyIdTarget.value.trim().length > 0
    const hasIdType = this.hasIdTypeTarget && this.idTypeTarget.value.trim().length > 0
    const hasIdNumber = this.hasIdNumberTarget && this.idNumberTarget.value.trim().length > 0
    const idRequired = !hasParty
    const hasValidId = !idRequired || (hasIdType && hasIdNumber)

    return checkAmountCents <= 0 || feeCents < 0 || feeCents > checkAmountCents || netCashPayoutCents <= 0 || !hasValidId
  }

  checkAccountReference(check, index) {
    const routing = check.routing || "unknown-routing"
    const account = check.account || "unknown-account"
    const number = check.number || `unknown-${index + 1}`
    return `check:${routing}:${account}:${number}`
  }

  effectiveAmountCents() {
    return this.checkCashingAmounts().netCashPayoutCents
  }

  resetFormFieldClearing(isAfterPost = false) {
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (this.hasFeeCentsTarget) this.setAmountCents(this.feeCentsTarget, 0)
    if (this.hasPartyIdTarget) this.partyIdTarget.value = ""
    if (this.hasIdTypeTarget) this.idTypeTarget.value = "drivers_license"
    if (this.hasIdNumberTarget) this.idNumberTarget.value = ""
    if (this.hasFeeIncomeAccountReferenceTarget) this.feeIncomeAccountReferenceTarget.value = "income:check_cashing_fee"
    if (this.hasCheckRowsTarget) this.checkRowsTarget.innerHTML = ""
    if (isAfterPost && this.hasCashAccountReferenceTarget) {
      this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    }
  }

  focusFirstField() {
    const feeWrapper = this.hasFeeCentsTarget ? this.feeCentsTarget.closest?.("[data-controller~=\"currency-input\"]") : null
    const displayInput = feeWrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
    if (displayInput && typeof displayInput.focus === "function") {
      displayInput.focus()
    } else if (this.hasFeeCentsTarget && typeof this.feeCentsTarget.focus === "function") {
      this.feeCentsTarget.focus()
    }
  }
}
