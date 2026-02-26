/**
 * Shared balancing for teller posting: build debit/credit entries from state
 * and compute totals. No DOM; pure functions. State shape is defined by the
 * controller's getState() so they stay in sync.
 *
 * State shape (plain object):
 * - transactionType, primaryAccountReference, counterpartyAccountReference, cashAccountReference
 * - amountCents, effectiveAmountCents (total for the transaction)
 * - checks: Array<{ account_reference, amount_cents, ... }>
 * - checkCashingAmounts: { checkAmountCents, feeCents, netCashPayoutCents }
 * - settlementAccountReference, feeIncomeAccountReference
 * - draftAmounts: { draftAmountCents, draftFeeCents, draftCashCents, draftAccountCents, draftCheckCents }
 * - draftLiabilityAccountReference, draftFeeIncomeAccountReference
 * - vaultTransferDetails: { valid, sourceReference, destinationReference }
 */

export function buildEntries(transactionType, state) {
  const entryProfile = state.entryProfile ?? transactionType
  const amountCents = state.effectiveAmountCents ?? 0
  const cashAmountCents = state.amountCents ?? 0
  const cashBackCents = state.cashBackCents ?? 0
  const checks = state.checks ?? []
  const primaryAccountReference = (state.primaryAccountReference ?? "").trim()
  const counterpartyAccountReference = (state.counterpartyAccountReference ?? "").trim()
  const cashAccountReference = (state.cashAccountReference ?? "").trim()
  const settlementAccountReference = (state.settlementAccountReference ?? "").trim()
  const feeIncomeAccountReference = (state.feeIncomeAccountReference ?? "income:check_cashing_fee").trim()
  const draftLiabilityAccountReference = (state.draftLiabilityAccountReference ?? "official_check:outstanding").trim()
  const draftFeeIncomeAccountReference = (state.draftFeeIncomeAccountReference ?? "income:draft_fee").trim()
  const draftAmountCents = state.draftAmounts?.draftAmountCents ?? 0
  const draftFeeCents = state.draftAmounts?.draftFeeCents ?? 0
  const { checkAmountCents = 0, feeCents = 0, netCashPayoutCents = 0 } = state.checkCashingAmounts ?? {}
  const vaultTransferDetails = state.vaultTransferDetails ?? { valid: false, sourceReference: "", destinationReference: "" }

  if (amountCents <= 0) {
    return []
  }

  if (entryProfile === "deposit") {
    const entries = []

    if (cashAmountCents > 0) {
      entries.push({ side: "debit", account_reference: cashAccountReference, amount_cents: cashAmountCents })
    }

    checks
      .filter((check) => (check.amount_cents ?? 0) > 0)
      .forEach((check) => {
        entries.push({
          side: "debit",
          account_reference: check.account_reference ?? "",
          amount_cents: check.amount_cents
        })
      })

    const totalDepositCents = cashAmountCents + checks.reduce((sum, c) => sum + (c.amount_cents ?? 0), 0)
    const cappedCashBackCents = Math.min(cashBackCents, totalDepositCents)
    if (cappedCashBackCents > 0 && cashAccountReference) {
      entries.push({ side: "credit", account_reference: cashAccountReference, amount_cents: cappedCashBackCents })
    }

    entries.push({ side: "credit", account_reference: primaryAccountReference, amount_cents: amountCents })
    return entries
  }

  if (entryProfile === "withdrawal") {
    return [
      { side: "debit", account_reference: primaryAccountReference, amount_cents: amountCents },
      { side: "credit", account_reference: cashAccountReference, amount_cents: amountCents }
    ]
  }

  if (entryProfile === "transfer") {
    const feeCents = state.transferAmounts?.feeCents ?? 0
    const transferFeeIncomeAccountReference = (state.transferFeeIncomeAccountReference ?? "income:transfer_fee").trim()
    const netToCounterparty = Math.max(amountCents - feeCents, 0)
    const entries = [
      { side: "debit", account_reference: primaryAccountReference, amount_cents: amountCents },
      { side: "credit", account_reference: counterpartyAccountReference, amount_cents: netToCounterparty }
    ]
    if (feeCents > 0 && transferFeeIncomeAccountReference) {
      entries.push({ side: "credit", account_reference: transferFeeIncomeAccountReference, amount_cents: feeCents })
    }
    return entries
  }

  if (entryProfile === "vault_transfer") {
    if (!vaultTransferDetails.valid) {
      return []
    }

    return [
      { side: "debit", account_reference: vaultTransferDetails.destinationReference, amount_cents: amountCents },
      { side: "credit", account_reference: vaultTransferDetails.sourceReference, amount_cents: amountCents }
    ]
  }

  if (entryProfile === "draft") {
    if (draftAmountCents <= 0 || !draftLiabilityAccountReference) {
      return []
    }

    const draftCashCents = state.draftAmounts?.draftCashCents ?? 0
    const draftAccountCents = state.draftAmounts?.draftAccountCents ?? 0
    const draftCheckCents = (state.checks ?? []).reduce((sum, c) => sum + (c.amount_cents ?? 0), 0)
    const totalPaymentCents = draftCashCents + draftAccountCents + draftCheckCents
    const totalDueCents = draftAmountCents + draftFeeCents
    if (totalPaymentCents !== totalDueCents) {
      return []
    }

    const entries = []

    if (draftCashCents > 0 && cashAccountReference) {
      entries.push({ side: "debit", account_reference: cashAccountReference, amount_cents: draftCashCents })
    }

    checks
      .filter((c) => (c.amount_cents ?? 0) > 0)
      .forEach((check) => {
        entries.push({ side: "debit", account_reference: check.account_reference ?? "", amount_cents: check.amount_cents })
      })

    const primaryUsed = primaryAccountReference &&
      primaryAccountReference !== "0" &&
      primaryAccountReference !== "acct:0"
    if (draftAccountCents > 0 && primaryUsed) {
      entries.push({ side: "debit", account_reference: primaryAccountReference, amount_cents: draftAccountCents })
    }

    entries.push({ side: "credit", account_reference: draftLiabilityAccountReference, amount_cents: draftAmountCents })

    if (draftFeeCents > 0) {
      entries.push({ side: "credit", account_reference: draftFeeIncomeAccountReference, amount_cents: draftFeeCents })
    }

    return entries
  }

  if (entryProfile === "check_cashing") {
    const checkItems = checks.filter((c) => (c.amount_cents ?? 0) > 0)
    if (checkItems.length === 0 || netCashPayoutCents <= 0) {
      return []
    }

    const entries = []

    checkItems.forEach((check) => {
      entries.push({
        side: "debit",
        account_reference: check.account_reference ?? "",
        amount_cents: check.amount_cents
      })
    })

    entries.push({ side: "credit", account_reference: cashAccountReference, amount_cents: netCashPayoutCents })

    if (feeCents > 0) {
      entries.push({ side: "credit", account_reference: feeIncomeAccountReference, amount_cents: feeCents })
    }

    return entries
  }

  return []
}

export function computeTotals(entries) {
  const debitTotal = entries
    .filter((entry) => entry.side === "debit")
    .reduce((sum, entry) => sum + (entry.amount_cents ?? 0), 0)
  const creditTotal = entries
    .filter((entry) => entry.side === "credit")
    .reduce((sum, entry) => sum + (entry.amount_cents ?? 0), 0)
  const imbalance = Math.abs(debitTotal - creditTotal)
  const balanced = debitTotal > 0 && creditTotal > 0 && imbalance === 0

  return { debitTotal, creditTotal, imbalance, balanced }
}
