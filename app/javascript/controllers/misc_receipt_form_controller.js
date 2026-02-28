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
    "unitAmountCents",
    "quantity",
    "miscTotalDisplay",
    "memoRow",
    "checkSection",
    "checkRows",
    "checkTemplate",
    "miscReceiptSection",
    "miscReceiptTypeSelect",
    "incomeAccountReference",
    "memo",
    "miscCashCents",
    "miscAccountCents",
    "miscCheckSubtotal",
    "miscTotalAmount",
    "miscBalance",
    "partyId"
  ]

  connect() {
    this.defaultCashAccountReference = this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : ""
    super.connect()
  }

  onMiscReceiptTypeChange(event) {
    const option = event.target.selectedOptions?.[0]
    if (option) {
      const incomeRef = option.dataset?.incomeRef ?? ""
      const defaultCents = option.dataset?.defaultCents ?? ""
      const memoRequired = option.dataset?.memoRequired === "1"
      if (this.hasIncomeAccountReferenceTarget) this.incomeAccountReferenceTarget.value = incomeRef
      if (this.hasMemoTarget) {
        this.memoTarget.required = memoRequired
        this.memoTarget.setAttribute("aria-required", memoRequired ? "true" : "false")
      }
      if (defaultCents && this.hasUnitAmountCentsTarget) {
        const currentCents = parseInt(this.unitAmountCentsTarget.value || "0", 10)
        if (currentCents === 0) {
          this.setAmountCents(this.unitAmountCentsTarget, parseInt(defaultCents, 10))
          const wrapper = this.unitAmountCentsTarget.closest?.("[data-controller~=\"currency-input\"]")
          const displayInput = wrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
          if (displayInput) {
            const dollars = parseInt(defaultCents, 10) / 100
            displayInput.value = dollars.toFixed(2)
          }
        }
      }
    }
    this.recalculate()
  }

  getState() {
    const transactionType = "misc_receipt"
    const miscAmounts = this.miscAmounts()
    const memoRequired = this.getMemoRequiredFromSelectedType()
    const checks = this.collectCheckRows()
    const effectiveAmountCents = miscAmounts.amountCents ?? 0
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
      feeIncomeAccountReference: "income:check_cashing_fee",
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
      miscAmounts,
      memoRequired,
      miscReceiptTypeId: this.hasMiscReceiptTypeSelectTarget ? this.miscReceiptTypeSelectTarget.value : "",
      incomeAccountReference: this.hasIncomeAccountReferenceTarget ? this.incomeAccountReferenceTarget.value : "",
      memo: this.hasMemoTarget ? this.memoTarget.value : ""
    }
  }

  recalculate() {
    const transactionType = "misc_receipt"
    const state = this.getState()
    const schemaSections = getSections(transactionType, this.workflowSchema)
    const showMiscReceiptSection = workflowHasSectionInConfig(transactionType, "misc_receipt", schemaSections)
    const showCheckSection = workflowHasSectionInConfig(transactionType, "checks", schemaSections)
    const miscAmounts = state.miscAmounts

    if (this.hasAmountCentsTarget) {
      this.setAmountCents(this.amountCentsTarget, miscAmounts.amountCents ?? 0)
    }
    if (this.hasMiscTotalDisplayTarget) {
      this.miscTotalDisplayTarget.textContent = this.formatCents(miscAmounts.amountCents ?? 0)
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

    const totalAmountCents = state.effectiveAmountCents
    const workflowContext = {
      miscAccountCents: miscAmounts.miscAccountCents ?? 0,
      miscCashCents: miscAmounts.miscCashCents ?? 0
    }
    const hasPrimaryAccount = state.primaryAccountReference.trim().length > 0
    const requiresPrimaryAccount = getRequiresPrimaryAccount(transactionType, this.workflowSchema, workflowContext)
    const requiresCashAccount = getRequiresCashAccount(transactionType, this.workflowSchema, workflowContext)
    const requiresParty = getRequiresParty(transactionType, this.workflowSchema)
    const hasServedParty = state.partyId.trim().length > 0
    const hasCashAccount = state.cashAccountReference.trim().length > 0
    const hasIncomeAccount = state.incomeAccountReference.trim().length > 0 || state.miscReceiptTypeId.trim().length > 0
    const hasMemo = state.memo.trim().length > 0
    const hasInvalidCheckRows = this.hasInvalidCheckRows()
    const hasInvalidMiscReceiptFields = this.hasInvalidMiscReceiptFields(miscAmounts, state)

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
      hasInvalidMiscReceiptFields,
      hasInvalidTransferFields: false,
      hasInvalidVaultTransferFields: false,
      balanced
    })

    if (this.hasCheckSectionTarget) this.checkSectionTarget.hidden = !showCheckSection
    if (this.hasMiscReceiptSectionTarget) this.miscReceiptSectionTarget.hidden = !showMiscReceiptSection
    if (this.hasPrimaryAccountReferenceTarget) {
      this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
      this.primaryAccountReferenceTarget.setAttribute("aria-required", requiresPrimaryAccount ? "true" : "false")
    }

    if (this.hasMiscCheckSubtotalTarget) this.miscCheckSubtotalTarget.textContent = this.formatCents(miscAmounts.miscCheckCents || 0)
    if (this.hasMiscTotalAmountTarget) this.miscTotalAmountTarget.textContent = `Total amount: ${this.formatCents(miscAmounts.amountCents || 0)}`
    if (this.hasMiscBalanceTarget) {
      const balance = miscAmounts.balanceCents ?? 0
      this.miscBalanceTarget.textContent = `Balance: ${this.formatCents(balance)}`
      this.miscBalanceTarget.classList.toggle("text-error", balance !== 0)
    }

    if (this.hasStatusBadgeTarget) this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    if (this.hasHeaderStatusTarget) this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"

    const cashImpact = calculateCashImpact(transactionType, { miscCashCents: miscAmounts.miscCashCents ?? 0 }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || !hasIncomeAccount || (memoRequired && !hasMemo) || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCashAccount && !hasCashAccount) || (requiresParty && !hasServedParty) || hasInvalidCheckRows || hasInvalidMiscReceiptFields
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
        cashAmountCents: miscAmounts.miscCashCents ?? 0,
        checkAmountCents: 0,
        feeCents: 0,
        draftAmountCents: 0,
        draftFeeCents: 0,
        checkSubtotalCents: miscAmounts.miscCheckCents ?? 0,
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

  miscAmounts() {
    const unitAmountCents = this.hasUnitAmountCentsTarget ? Math.max(parseInt(this.unitAmountCentsTarget.value || "0", 10), 0) : 0
    const quantity = this.hasQuantityTarget ? Math.max(parseInt(this.quantityTarget.value || "1", 10), 1) : 1
    const amountCents = unitAmountCents * quantity
    const miscCashCents = this.hasMiscCashCentsTarget ? Math.max(parseInt(this.miscCashCentsTarget.value || "0", 10), 0) : 0
    const miscAccountCents = this.hasMiscAccountCentsTarget ? Math.max(parseInt(this.miscAccountCentsTarget.value || "0", 10), 0) : 0
    const miscCheckCents = this.checkSubtotalCents()

    return {
      unitAmountCents,
      quantity,
      amountCents,
      miscCashCents,
      miscAccountCents,
      miscCheckCents,
      totalPaymentCents: miscCashCents + miscAccountCents + miscCheckCents,
      balanceCents: amountCents - (miscCashCents + miscAccountCents + miscCheckCents)
    }
  }

  getMemoRequiredFromSelectedType() {
    if (!this.hasMiscReceiptTypeSelectTarget) return false
    const option = this.miscReceiptTypeSelectTarget.selectedOptions?.[0]
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

  hasInvalidMiscReceiptFields(miscAmounts, state) {
    const { amountCents = 0, balanceCents = 0 } = miscAmounts
    const hasTypeOrIncome = (state.miscReceiptTypeId ?? "").trim().length > 0 || (state.incomeAccountReference ?? "").trim().length > 0
    const memoRequired = state.memoRequired ?? false
    const hasMemo = (state.memo ?? "").trim().length > 0
    return amountCents <= 0 || !hasTypeOrIncome || balanceCents !== 0 || (memoRequired && !hasMemo)
  }

  checkAccountReference(check, index) {
    const routing = check.routing || "unknown-routing"
    const account = check.account || "unknown-account"
    const number = check.number || `unknown-${index + 1}`
    return `check:${routing}:${account}:${number}`
  }

  effectiveAmountCents() {
    return this.miscAmounts().amountCents ?? 0
  }

  resetFormFieldClearing(isAfterPost = false) {
    if (this.hasPrimaryAccountReferenceTarget) this.primaryAccountReferenceTarget.value = ""
    if (this.hasPartyIdTarget) this.partyIdTarget.value = ""
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (this.hasUnitAmountCentsTarget) this.setAmountCents(this.unitAmountCentsTarget, 0)
    if (this.hasQuantityTarget) this.quantityTarget.value = "1"
    if (this.hasMiscCashCentsTarget) this.setAmountCents(this.miscCashCentsTarget, 0)
    if (this.hasMiscAccountCentsTarget) this.setAmountCents(this.miscAccountCentsTarget, 0)
    if (this.hasMemoTarget) {
      this.memoTarget.value = ""
      this.memoTarget.required = false
    }
    if (this.hasMiscReceiptTypeSelectTarget) this.miscReceiptTypeSelectTarget.value = ""
    if (this.hasIncomeAccountReferenceTarget) this.incomeAccountReferenceTarget.value = ""
    if (this.hasCheckRowsTarget) this.checkRowsTarget.innerHTML = ""
    const unitWrapper = this.unitAmountCentsTarget?.closest?.("[data-controller~=\"currency-input\"]")
    const displayInput = unitWrapper?.querySelector?.("[data-currency-input-target=\"displayInput\"]")
    if (displayInput) displayInput.value = ""
    if (isAfterPost && this.hasCashAccountReferenceTarget) {
      this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    }
  }

  focusFirstField() {
    const firstField = this.hasMiscReceiptTypeSelectTarget ? this.miscReceiptTypeSelectTarget : (this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget : null)
    if (firstField && typeof firstField.focus === "function") firstField.focus()
  }
}
