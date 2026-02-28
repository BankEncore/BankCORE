import PostingFormBase from "services/posting_form_base"
import { buildEntries, computeTotals, calculateCashImpact } from "services/posting_balance"
import {
  getSections,
  getEntryProfile,
  getEffectiveAmountSource,
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
    "cashAmountRow",
    "checkSection",
    "checkRows",
    "checkTemplate",
    "cashBackRow",
    "cashBackCents",
    "computedCashSubtotal",
    "computedCheckSubtotal",
    "computedCashBackRow",
    "computedCashBackSubtotal",
    "computedFeeSubtotal",
    "computedNetTotal",
    "availabilitySection",
    "availabilityBody",
    "availabilityEmpty"
  ]

  connect() {
    this.defaultCashAccountReference = this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : ""
    super.connect()
  }

  getState() {
    const transactionType = "deposit"
    const checks = this.collectCheckRows()
    const effectiveAmountCents = this.effectiveAmountCents()
    const entryProfile = getEntryProfile(transactionType, this.workflowSchema)

    return {
      transactionType,
      entryProfile,
      primaryAccountReference: this.hasPrimaryAccountReferenceTarget ? this.primaryAccountReferenceTarget.value : "",
      counterpartyAccountReference: "",
      cashAccountReference: this.hasCashAccountReferenceTarget ? this.cashAccountReferenceTarget.value : "",
      amountCents: parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10),
      cashBackCents: this.cashBackCents(),
      effectiveAmountCents,
      checks,
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
    const transactionType = "deposit"
    const state = this.getState()
    const checkSubtotalCents = this.checkSubtotalCents()
    const totalAmountCents = state.effectiveAmountCents
    const hasPrimaryAccount = state.primaryAccountReference.trim().length > 0
    const requiresPrimaryAccount = getRequiresPrimaryAccount(transactionType, this.workflowSchema, {})
    const requiresCashAccount = getRequiresCashAccount(transactionType, this.workflowSchema, {})
    const hasCashAccount = state.cashAccountReference.trim().length > 0
    const hasInvalidCheckRows = this.hasInvalidCheckRows()

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
      hasInvalidCheckRows,
      hasInvalidCheckCashingFields: false,
      hasInvalidDraftFields: false,
      hasInvalidTransferFields: false,
      hasInvalidVaultTransferFields: false,
      balanced
    })

    if (this.hasCheckSectionTarget) {
      this.checkSectionTarget.hidden = false
    }
    if (this.hasCashBackRowTarget) {
      this.cashBackRowTarget.hidden = false
    }
    if (this.hasCashBackCentsTarget) {
      const totalDepositCents = Math.max(state.amountCents, 0) + checkSubtotalCents
      const enteredCashBack = this.cashBackCents()
      if (totalDepositCents > 0 && enteredCashBack > totalDepositCents) {
        this.setAmountCents(this.cashBackCentsTarget, totalDepositCents)
      }
    }
    if (this.hasPrimaryAccountReferenceTarget) {
      this.primaryAccountReferenceTarget.required = requiresPrimaryAccount
      this.primaryAccountReferenceTarget.setAttribute("aria-required", requiresPrimaryAccount ? "true" : "false")
    }

    if (this.hasComputedCashSubtotalTarget) this.computedCashSubtotalTarget.textContent = this.formatCents(displayedCashAmount)
    if (this.hasComputedCheckSubtotalTarget) this.computedCheckSubtotalTarget.textContent = this.formatCents(checkSubtotalCents)
    const cashBackCentsForComputed = this.cashBackCents()
    if (this.hasComputedCashBackRowTarget) {
      this.computedCashBackRowTarget.hidden = cashBackCentsForComputed <= 0
      if (this.hasComputedCashBackSubtotalTarget) this.computedCashBackSubtotalTarget.textContent = this.formatCents(cashBackCentsForComputed)
    }
    if (this.hasComputedFeeSubtotalTarget) this.computedFeeSubtotalTarget.textContent = this.formatCents(0)
    if (this.hasComputedNetTotalTarget) this.computedNetTotalTarget.textContent = this.formatCents(totalAmountCents)

    if (this.hasStatusBadgeTarget) {
      this.setBalanceBadge(balanced ? "Balanced" : "Out of Balance")
    }
    if (this.hasHeaderStatusTarget) {
      this.headerStatusTarget.textContent = balanced ? "Balanced" : "Editing"
    }

    const cashImpact = calculateCashImpact(transactionType, { amountCents: displayedCashAmount }, this.workflowSchema)
    const projectedDrawer = (this.openingCashCentsValue || 0) + cashImpact

    const hasMissingFields = totalAmountCents <= 0 || (requiresPrimaryAccount && !hasPrimaryAccount) || (requiresCashAccount && !hasCashAccount) || hasInvalidCheckRows
    let disabled = blockedReason.length > 0 || !balanced || hasMissingFields
    if (this.postedLocked) disabled = true

    this.submitButtonTarget.disabled = disabled
    if (this.hasHeaderSubmitButtonTarget) {
      this.headerSubmitButtonTarget.disabled = disabled
    }

    if (balanced) this.setHeaderState("Balanced")
    else this.setHeaderState("Editing")

    if (this.hasPostingPreviewBodyTarget) {
      this.renderPostingPreview(entries)
    }

    if (this.hasAvailabilitySectionTarget) {
      this.availabilitySectionTarget.hidden = false
      this.renderFundsAvailability(state)
    }

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
        checkAmountCents: checkSubtotalCents,
        feeCents: 0,
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

  effectiveAmountCents() {
    const baseAmount = parseInt((this.hasAmountCentsTarget ? this.amountCentsTarget.value : "0") || "0", 10)
    const cashAmount = Math.max(baseAmount, 0)
    const totalDeposit = cashAmount + this.checkSubtotalCents()
    const cashBackCents = Math.min(this.cashBackCents(), totalDeposit)
    return Math.max(totalDeposit - cashBackCents, 0)
  }

  cashBackCents() {
    if (!this.hasCashBackCentsTarget) return 0
    return Math.max(parseInt(this.cashBackCentsTarget.value || "0", 10), 0)
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

  checkAccountReference(check, index) {
    const routing = check.routing || "unknown-routing"
    const account = check.account || "unknown-account"
    const number = check.number || `unknown-${index + 1}`
    return `check:${routing}:${account}:${number}`
  }

  resetFormFieldClearing(isAfterPost = false) {
    if (this.hasPrimaryAccountReferenceTarget) this.primaryAccountReferenceTarget.value = ""
    if (this.hasAmountCentsTarget) this.setAmountCents(this.amountCentsTarget, 0)
    if (this.hasCashBackCentsTarget) this.setAmountCents(this.cashBackCentsTarget, 0)
    if (isAfterPost && this.hasCashAccountReferenceTarget) {
      this.cashAccountReferenceTarget.value = this.defaultCashAccountReference || ""
    }
    if (this.hasCheckRowsTarget) this.checkRowsTarget.innerHTML = ""
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

  addBusinessDays(date, days) {
    const d = new Date(date)
    let count = 0
    while (count < days) {
      d.setDate(d.getDate() + 1)
      if (d.getDay() !== 0 && d.getDay() !== 6) count++
    }
    return d
  }

  computeDepositAvailabilityRows(cashInFromCashCents, checkItems, cashBackCents = 0) {
    const rows = []
    const asOf = new Date()
    let remainingCashBack = Math.max(0, cashBackCents)

    const immediateCents = Math.max(0, cashInFromCashCents || 0)
    if (immediateCents > 0) {
      const deduct = Math.min(remainingCashBack, immediateCents)
      remainingCashBack -= deduct
      const netCents = immediateCents - deduct
      if (netCents > 0) rows.push({ label: "Immediate", date: asOf, amountCents: netCents })
    }

    const held = checkItems.filter((i) => (i.hold_reason || "").toString().trim().length > 0)
    const nonHeld = checkItems.filter((i) => (i.hold_reason || "").toString().trim().length === 0)
    const nonHeldTotal = nonHeld.reduce((sum, i) => sum + (i.amount_cents || 0), 0)

    if (nonHeldTotal > 0) {
      const first250Cents = Math.min(25_000, nonHeldTotal)
      const restCents = nonHeldTotal - first250Cents
      const nextBiz = this.addBusinessDays(asOf, 1)
      const twoBiz = this.addBusinessDays(asOf, 2)

      const deductFirst250 = Math.min(remainingCashBack, first250Cents)
      remainingCashBack -= deductFirst250
      const netFirst250 = first250Cents - deductFirst250
      if (netFirst250 > 0) {
        rows.push({
          label: nextBiz.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" }),
          date: nextBiz,
          amountCents: netFirst250
        })
      }

      const deductRest = Math.min(remainingCashBack, restCents)
      remainingCashBack -= deductRest
      const netRest = restCents - deductRest
      if (netRest > 0) {
        rows.push({
          label: twoBiz.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" }),
          date: twoBiz,
          amountCents: netRest
        })
      }
    }

    const heldByDate = {}
    held.forEach((i) => {
      const dateStr = (i.hold_until || "").toString().trim()
      if (!dateStr) return
      const date = new Date(dateStr)
      if (isNaN(date.getTime())) return
      const key = dateStr
      if (!heldByDate[key]) heldByDate[key] = { date, amountCents: 0 }
      heldByDate[key].amountCents += i.amount_cents || 0
    })
    const heldRows = Object.values(heldByDate)
      .map(({ date, amountCents }) => ({
        label: date.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" }),
        date,
        amountCents
      }))
      .sort((a, b) => a.date - b.date)

    heldRows.forEach((row) => {
      const deduct = Math.min(remainingCashBack, row.amountCents)
      remainingCashBack -= deduct
      const netCents = row.amountCents - deduct
      if (netCents > 0) rows.push({ ...row, amountCents: netCents })
    })

    rows.sort((a, b) => {
      const aOrder = a.label === "Immediate" ? 0 : 1
      const bOrder = b.label === "Immediate" ? 0 : 1
      if (aOrder !== bOrder) return aOrder - bOrder
      return a.date - b.date
    })
    return rows
  }

  renderFundsAvailability(state) {
    if (!this.hasAvailabilityBodyTarget || !this.hasAvailabilityEmptyTarget) return

    const cashInFromCashCents = state.amountCents || 0
    const checkItems = this.collectCheckRows().filter((c) => (c.amount_cents || 0) > 0)
    const cashBackCents = state.cashBackCents ?? this.cashBackCents()
    const rows = this.computeDepositAvailabilityRows(cashInFromCashCents, checkItems, cashBackCents)

    this.availabilityBodyTarget.innerHTML = ""
    this.availabilityEmptyTarget.hidden = rows.length > 0

    rows.forEach((row) => {
      const tr = document.createElement("tr")
      tr.innerHTML = `
        <td>${row.label.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}</td>
        <td class="text-right tabular-nums">${this.formatCents(row.amountCents)}</td>
      `
      this.availabilityBodyTarget.appendChild(tr)
    })
  }
}
