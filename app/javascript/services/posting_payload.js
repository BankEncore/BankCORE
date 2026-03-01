/**
 * Append posting entries and type-specific payload to FormData.
 * Mirrors server expectations so posting behavior is unchanged.
 */

import { buildEntries } from "services/posting_balance"
import { hasSection } from "services/posting_workflows"

export function appendEntriesAndTypePayload(formData, transactionType, state, schema = null) {
  const entries = buildEntries(transactionType, state)
  entries.forEach((entry) => {
    formData.append("entries[][side]", entry.side)
    formData.append("entries[][account_reference]", entry.account_reference)
    formData.append("entries[][amount_cents]", String(entry.amount_cents))
  })

  if (hasSection(transactionType, "checks", schema)) {
    appendCheckItems(formData, state)
  }
  if (transactionType === "deposit") {
    formData.set("cash_back_cents", String(state.cashBackCents ?? 0))
  }
  if (["deposit", "withdrawal", "transfer", "draft", "check_cashing", "misc_receipt", "bill_payment"].includes(transactionType)) {
    appendServedPartyPayload(formData, state)
  }
  if (transactionType === "check_cashing") {
    appendCheckCashingPayload(formData, state)
  }
  if (transactionType === "draft") {
    appendDraftPayload(formData, state)
  }
  if (transactionType === "misc_receipt") {
    appendMiscReceiptPayload(formData, state)
  }
  if (transactionType === "vault_transfer") {
    appendVaultTransferPayload(formData, state)
  }
  if (transactionType === "transfer") {
    appendTransferPayload(formData, state)
  }
  if (transactionType === "bill_payment") {
    appendBillPaymentPayload(formData, state)
  }
  appendDenominationLines(formData, state)
}

function appendDenominationLines(formData, state) {
  const lines = state.denominationLines ?? []
  if (lines.length === 0) return

  lines.forEach((line) => {
    if ((line.amount_cents ?? 0) <= 0) return
    formData.append("denomination_lines[][cash_denomination_id]", String(line.cash_denomination_id ?? ""))
    formData.append("denomination_lines[][qty]", String(line.qty ?? 0))
    formData.append("denomination_lines[][amount_cents]", String(line.amount_cents ?? 0))
  })
}

function appendBillPaymentPayload(formData, state) {
  const bp = state.billPaymentAmounts ?? {}
  formData.set("payee_id", (state.payeeId ?? "").trim())
  formData.set("payee_reference", (state.payeeReference ?? "").trim())
  formData.set("payment_cents", String(bp.paymentCents ?? 0))
  formData.set("fee_cents", String(bp.feeCents ?? 0))
  formData.set("amount_cents", String(bp.totalDueCents ?? 0))
  formData.set("liability_account_reference", (state.liabilityAccountReference ?? "").trim())
  formData.set("memo", (state.memo ?? "").trim())
  formData.set("bill_payment_cash_cents", String(bp.billPaymentCashCents ?? 0))
  formData.set("bill_payment_account_cents", String(bp.billPaymentAccountCents ?? 0))
}

function appendCheckItems(formData, state) {
  const checks = state.checks ?? []
  checks
    .filter((check) => (check.amount_cents ?? 0) > 0)
    .forEach((check) => {
      formData.append("check_items[][routing]", check.routing ?? "")
      formData.append("check_items[][account]", check.account ?? "")
      formData.append("check_items[][number]", check.number ?? "")
      formData.append("check_items[][account_reference]", check.account_reference ?? "")
      formData.append("check_items[][amount_cents]", String(check.amount_cents ?? 0))
      formData.append("check_items[][check_type]", check.check_type ?? "transit")
      formData.append("check_items[][hold_reason]", check.hold_reason ?? "")
      formData.append("check_items[][hold_until]", check.hold_until ?? "")
    })
}

function appendDraftPayload(formData, state) {
  const { draftAmountCents = 0, draftFeeCents = 0, draftCashCents = 0, draftAccountCents = 0 } = state.draftAmounts ?? {}
  formData.set("draft_amount_cents", String(draftAmountCents))
  formData.set("draft_fee_cents", String(draftFeeCents))
  formData.set("draft_cash_cents", String(draftCashCents))
  formData.set("draft_account_cents", String(draftAccountCents))
  formData.set("draft_payee_name", (state.draftPayeeName ?? "").trim())
  formData.set("draft_instrument_number", (state.draftInstrumentNumber ?? "").trim())
  formData.set("draft_liability_account_reference", (state.draftLiabilityAccountReference ?? "official_check:outstanding").trim())
  formData.set("draft_fee_income_account_reference", (state.draftFeeIncomeAccountReference ?? "income:draft_fee").trim())
}

function appendMiscReceiptPayload(formData, state) {
  const misc = state.miscAmounts ?? {}
  formData.set("misc_receipt_type_id", (state.miscReceiptTypeId ?? "").trim())
  formData.set("income_account_reference", (state.incomeAccountReference ?? "").trim())
  formData.set("amount_cents", String(misc.amountCents ?? 0))
  formData.set("unit_amount_cents", String(misc.unitAmountCents ?? 0))
  formData.set("quantity", String(misc.quantity ?? 1))
  formData.set("memo", (state.memo ?? "").trim())
  formData.set("misc_cash_cents", String(misc.miscCashCents ?? 0))
  formData.set("misc_account_cents", String(misc.miscAccountCents ?? 0))
}

function appendVaultTransferPayload(formData, state) {
  const details = state.vaultTransferDetails ?? {}
  formData.set("vault_transfer_direction", details.direction ?? "")
  formData.set("vault_transfer_source_cash_account_reference", details.sourceReference ?? "")
  formData.set("vault_transfer_destination_cash_account_reference", details.destinationReference ?? "")
  formData.set("vault_transfer_reason_code", details.reasonCode ?? "")
  formData.set("vault_transfer_memo", details.memo ?? "")
}

function appendServedPartyPayload(formData, state) {
  formData.set("party_id", (state.partyId ?? "").trim())
}

function appendCheckCashingPayload(formData, state) {
  const amounts = state.checkCashingAmounts ?? {}
  formData.set("fee_cents", String(amounts.feeCents ?? 0))
  formData.set("fee_income_account_reference", (state.feeIncomeAccountReference ?? "income:check_cashing_fee").trim())
}

function appendTransferPayload(formData, state) {
  const amounts = state.transferAmounts ?? {}
  formData.set("fee_cents", String(amounts.feeCents ?? 0))
  formData.set("fee_income_account_reference", (state.transferFeeIncomeAccountReference ?? "income:transfer_fee").trim())
}
