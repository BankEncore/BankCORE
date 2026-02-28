import PostingFormBase from "services/posting_form_base"
import { buildEntries, computeTotals, calculateCashImpact } from "services/posting_balance"
import {
  getSections,
  getEntryProfile,
  getRequiresPrimaryAccount,
  getRequiresCashAccount,
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
    "checkSection",
    "checkRows",
    "checkTemplate",
    "draftSection",
    "draftAmountCents",
    "draftFeeCents",
    "draftCashCents",
    "draftAccountCents",
    "draftCheckSubtotal",
    "draftTotalDue",
    "draftBalance",
    "draftPayeeName",
    "draftInstrumentNumber",
    "draftLiabilityAccountReference",
    "draftFeeIncomeAccountReference",
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
    const transactionType = "draft"
    const draftAmounts = this.draftAmounts()
    const checks = this.collectCheckRows()
    const effectiveAmountCents = draftAmounts.totalDueCents ?? 0
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget.value : "",
      counterpartyAccountReference: "",
      cashAccountReference: this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "",
      amountCents: draftAmounts.draftAmountCents ?? 0,
      cashBackCents: 0,
      effectiveAmountCents,
      checks,
      checkCashingAmounts: { checkAmountCents: 0, feeCents: 0, netCashPayoutCents: 0 },
      settlementAccountReference: "",
      feeIncomeAccountReference: "income:check_cashing_fee",
      draftAmounts,
      draftLiabilityAccountReference: this.hasDraftLiabilityAccountReferenceTarget ? this.draftLiabilityAccountReferenceTarget.value : "official_check:outstanding",
      draftFeeIncomeAccountReference: this.hasDraftFeeIncomeAccountReferenceTarget ? this.draftFeeIncomeAccountReferenceTarget.value : "income:draft_fee",
      draftPayeeName: this.hasDraftPayeeNameTarget ? this.draftPayeeNameTarget.value : "",
      draftInstrumentNumber: this.hasDraftInstrumentNumberTarget ? this.draftInstrumentNumberTarget.value : "",
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
    const transactionType = "draft"
    const state = this.getState()
    const schemaSections = getSections(transactionType, this.workflowSchema)
    const showDraftSection = workflowHasSectionInConfig(transactionType, "draft", schemaSections)
    const showCheckSection = workflowHasSectionInConfig(transactionType, "checks", schemaSections)
    const draftAmounts = state.draftAmounts

    if (this.hasAmountCentsTarget) {
      this.setAmountCents(this.amountCentsTarget, draftAmounts.draftAmountCents ?? 0)
    }

    const totalAmountCents = state.effectiveAmountCents
    const workflowContext = {
      draftAccountCents: draftAmounts.draftAccountCents ?? 0,
      draftCashCents: draftAmounts.draftCashCents ?? 0
    }
    const hasPrimaryAccount = state.primaryAccountReference.trim().length > 0
    const requiresPrimaryAccount = getRequiresPrimaryAccount(transactionType, this.workflowSchema, workflowContext)
    const requiresCashAccount = getRequiresCashAccount(transactionType, this.workflowSchema, workflowContext)
    const hasCashAccount = state.cashAccountReference.trim().length > 0
    const hasDraftPayee = state.draftPayeeName.trim().length > 0
    const hasDraftInstrumentNumber = state.draftInstrumentNumber.trim().length > 0
    const hasDraftLiabilityAccount = state.draftLiabilityAccountReference.trim().length > 0
    const requiresDraftDetails = showDraftSection
    const hasInvalidCheckRows = this.hasInvalidCheckRows()
    const hasInvalidDraftFields = this.hasInvalidDraftFields(draftAmounts)

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
      requiresParty: false,
      hasParty: false,
      requiresDraftDetails,
      hasDraftPayee,
      hasDraftInstrumentNumber,
      hasDraftLiabilityAccount,
      requiresVaultTransferDetails: false,
      hasVaultDirection: false,
      hasVaultReasonCode: false,
      hasVaultMemo: false,
      hasVaultEndpoints: false,
      hasInvalidCheckRows,
      hasInvalidCheckCashingFields: false,
      hasInvalidDraftFields,
      hasInvalidTransferFields: false,
      hasInvalidVaultTransferFields: false,
      balanced
    })

    if (this.hasCheckSectionTarget) this.checkSectionTarget.hidden = !showCheckSection
    if (this.hasDraftSectionTarget) this.draftSectionTarget.hidden = !showDraftSection
    if (this.hasPrimaryAccountReferenceTarget) {
      this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
      this.primaryAccountReferenceTarget.setAttribute("aria-required", requiresPrimaryAccount ? "true" : "false")
    }
    if (this.hasAmountCentsTarget) this.amountCentsTarget.readOnly = true

    if (this.hasComputedCashSubtotalTarget) this.computedCashSubtotalTarget.textContent = this.formatCents(draftAmounts.draftCashCents ?? 0)
    if (this.hasComputedCheckSubtotalTarget) this.computedCheckSubtotalTarget.textContent = this.formatCents(draftAmounts.draftCheckCents ?? 0)
    if (this.hasComputedFeeSubtotalTarget) {
      const feeCents = draftAmounts.draftFeeCents ?? 0
      this.computedFeeSubtotalTarget.textContent = feeCents > 0 ? `-${this.formatCents(feeCents)}` : this.formatCents(0)
    }
    if (this.hasComputedNetTotalTarget) this.computedNetTotalTarget.textContent = this.formatCents(totalAmountCents)
    if (showDraftSection && this.hasDraftCheckSubtotalTarget) this.draftCheckSubtotalTarget.textContent = this.formatCents(draftAmounts.draftCheckCents || 0)
    if (showDraftSection && this.hasDraftTotalDueTarget) this.draftTotalDueTarget.textContent = `Total due: ${this.formatCents(draftAmounts.totalDueCents || 0)}`
    if (showDraftSection && this.hasDraftBalanceTarget) {
      const balance = draftAmounts.balanceCents ?? 0
      this.draftBalanceTarget.textContent = `Balance: ${this.formatCents(balance)}`
      this.draftBalanceTarget.classList.toggle("text-error", balance !== 0)
    }

    if (this.hasStatusBadgeTarget) this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"

    const cashImpact = calculateCashImpact(transactionType, { amountCents: 0, draftCashCents: draftAmounts.draftCashCents ?? 0 }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCashAccount && !hasCashAccount) || (requiresDraftDetails && (!hasDraftPayee || !hasDraftInstrumentNumber || !hasDraftLiabilityAccount)) || hasInvalidCheckRows || hasInvalidDraftFields
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
        cashAmountCents: draftAmounts.draftCashCents ?? 0,
        checkAmountCents: 0,
        feeCents: 0,
        draftAmountCents: draftAmounts.draftAmountCents ?? 0,
        draftFeeCents: draftAmounts.draftFeeCents ?? 0,
        checkSubtotalCents: draftAmounts.draftCheckCents ?? 0,
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

  draftAmounts() {
    const draftAmountCents = this.hasDraftAmountCentsTarget ? Math.max(parseInt(this.draftAmountCentsTarget.value || "0", 10), 0) : 0
    const draftFeeCents = this.hasDraftFeeCentsTarget ? Math.max(parseInt(this.draftFeeCentsTarget.value || "0", 10), 0) : 0
    const draftCashCents = this.hasDraftCashCentsTarget ? Math.max(parseInt(this.draftCashCentsTarget.value || "0", 10), 0) : 0
    const draftAccountCents = this.hasDraftAccountCentsTarget ? Math.max(parseInt(this.draftAccountCentsTarget.value || "0", 10), 0) : 0
    const draftCheckCents = this.checkSubtotalCents()

    return {
      draftAmountCents,
      draftFeeCents,
      draftCashCents,
      draftAccountCents,
      draftCheckCents,
      totalDueCents: draftAmountCents + draftFeeCents,
      totalPaymentCents: draftCashCents + draftAccountCents + draftCheckCents,
      balanceCents: draftAmountCents + draftFeeCents - (draftCashCents + draftAccountCents + draftCheckCents)
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

  hasInvalidDraftFields(draftAmounts) {
    const { draftAmountCents = 0, draftFeeCents = 0, balanceCents = 0 } = draftAmounts
    return draftAmountCents <= 0 || draftFeeCents < 0 || balanceCents !== 0
  }

  checkAccountReference(check, index) {
    const routing = check.routing || "unknown-routing"
    const account = check.account || "unknown-account"
    const number = check.number || `unknown-${index + 1}`
    return `check:${routing}:${account}:${number}`
  }

  effectiveAmountCents() {
    return (this.draftAmounts().totalDueCents ?? 0)
  }

  resetFormFieldClearing(isAfterPost = false) {
    if (this.hasPrimaryAccountReferenceTarget) this.primaryAccountReferenceTarget.value = ""
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (this.hasDraftAmountCentsTarget) this.setAmountCents(this.draftAmountCentsTarget, 0)
    if (this.hasDraftFeeCentsTarget) this.setAmountCents(this.draftFeeCentsTarget, 0)
    if (this.hasDraftCashCentsTarget) this.setAmountCents(this.draftCashCentsTarget, 0)
    if (this.hasDraftAccountCentsTarget) this.setAmountCents(this.draftAccountCentsTarget, 0)
    if (this.hasDraftPayeeNameTarget) this.draftPayeeNameTarget.value = ""
    if (this.hasDraftInstrumentNumberTarget) this.draftInstrumentNumberTarget.value = ""
    if (this.hasDraftLiabilityAccountReferenceTarget) this.draftLiabilityAccountReferenceTarget.value = "official_check:outstanding"
    if (this.hasDraftFeeIncomeAccountReferenceTarget) this.draftFeeIncomeAccountReferenceTarget.value = "income:draft_fee"
    if (this.hasCheckRowsTarget) this.checkRowsTarget.innerHTML = ""
    if (isAfterPost && this.hasCashAccountReferenceTarget) {
      this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    }
  }

  focusFirstField() {
    const firstField = (this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget : null) || (this.hasDraftAmountCentsTarget ? this.draftAmountCentsTarget : null)
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
