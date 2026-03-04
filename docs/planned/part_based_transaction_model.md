# Part-Based Transaction Model

## Overview

This document describes a proposed refactor of teller (and eventually non-teller) posting flows into a **part-based transaction model**. The model expresses each transaction as a composition of standardized "parts" (CI, CO, CK, PAD, PAC, FEE, etc.) with equations that define valid compositions and enforce balance.

---

## Motivation

### Current Issues

1. **Inconsistent fee semantics** — Fees behave differently by flow: "withheld" (reduces payout) vs. "added" (increases total due).

2. **Check cashing confusion** — After removing legacy fee fields, disbursement is shown as the full check total. There is no way to represent "fee withheld from payout" using misc additions alone (which debit from primary account—often absent for walk-ins).

3. **Flow-specific logic** — Each transaction type has its own recipe, validator, and form logic. Fee handling, balance checks, and entry construction are duplicated and diverge.

4. **Limited reuse for non-teller** — The Engine accepts balanced entries, but entry construction is coupled to teller flows and recipes.

---

## Part Vocabulary

| Part | Description | Debit/Credit |
|------|-------------|--------------|
| **CI** | Cash in (to drawer) | DB cash:location |
| **CO** | Cash out (from drawer) | CR cash:location |
| **CK** | Checks in (repeatable) | DB check:details |
| **PAC** | Primary account credit | CR acct:primary |
| **PAD** | Primary account debit | DB acct:primary |
| **CAC** | Counter-account credit | CR acct:counterparty |
| **CAD** | Counter-account debit | DB acct:counterparty |
| **BD** | Bank draft amount | CR draft:liability |
| **BP** | Bill payment amount | CR bill_pmt:payee |
| **FEE** | Fee income (repeatable) | CR income:* |

---

## Flow Equations

Each flow is defined by an equation. Debits = Credits is always enforced.

### Deposit
```
CI + CK - CO - FEE = PAC
Net deposit to primary = cash in + checks in - cash back - fees
```

### Withdrawal
```
CO + FEE = PAD
Cash out + fees = debit from primary
```

### Transfer
```
CAC + FEE = PAD
Amount to counterparty + fee = debit from primary (from account)
```

### Check Cashing
```
CK = CO + FEE
Checks in = cash out (disbursement) + fee withheld
Disbursement = CK - FEE
```

### Bill Payment
```
BP + FEE = Total Due
CI + CK + PAD = Payments
Payments must equal Total Due
```

### Bank Draft
```
BD + FEE = Total Due
CI + CK + PAD = Payments
Payments must equal Total Due
```

### Misc Receipt
```
FEE = CI + CK + PAD
Fees paid by cash, checks, or account
```

---

## Benefits

1. **Unified fee semantics** — FEE is always a credit to fee income. Its effect depends on the equation: withheld (reduces CO or CAC) or added (increases total due).

2. **Consistent check cashing** — Disbursement is correctly computed as CK − FEE without needing a primary account for the fee.

3. **Single balance rule** — All flows satisfy debits = credits via the equations.

4. **Extensible to non-teller** — Same parts can describe interest accrual, fee assessments, ACH, wires, and generic GL adjustments.

5. **Shared construction layer** — A `TransactionBuilder` converts parts → entries for any flow, supporting both teller and system postings.

---

## Downsides & Mitigations

| Downside | Mitigation |
|----------|------------|
| Migration risk | PoC in isolation; no production path changes |
| Abstraction overhead | Start with one flow; expand only if useful |
| YAGNI for non-teller | PoC focused on teller flows first |
| Two systems during migration | Additive PoC; integration only when ready |

---

# Proof of Concept Plan

## Goal

Prove the part-based model works for at least one flow (check cashing) without changing production behavior.

## Branch Strategy

- Create a new branch from **main** (not the fee-refactor branch).
- Keep the PoC independent and additive.

## Scope

### Phase 1: Isolated Module (Check Cashing Only)

1. **Add new namespace**: `app/services/posting/parts/`
2. **Implement**:
   - `TransactionParts` — value object holding part amounts (CK, CO, FEE, references)
   - `PartBuilder` — dispatches to flow-specific builders
   - `Flows::CheckCashingFlow` — validates CK = CO + FEE and builds entries
3. **No integration** — no controller, route, or Engine changes.

### Phase 2: Unit Tests

1. **Balance** — entries from PartBuilder sum to zero.
2. **Correct legs** — check debit, cash credit, fee credit match expected amounts.
3. **Validation** — invalid parts (e.g. FEE > CK) raise or return errors.
4. **Parity (optional)** — when FEE = 0, entries match `CheckCashingRecipe` output.

### Phase 3: Validation & Iteration

1. Add a second flow (e.g. Transfer or Deposit) if the model still looks promising.
2. Optionally add a rake task or dev endpoint to build entries manually.
3. Decide whether to integrate or keep as a design reference.

## File Structure

```
app/services/posting/parts/
  transaction_parts.rb
  part_builder.rb
  flows/
    base_flow.rb
    check_cashing_flow.rb

test/services/posting/parts/
  part_builder_test.rb
  flows/
    check_cashing_flow_test.rb
```

## Success Criteria

- [ ] Check cashing parts (CK, FEE, cash ref) produce balanced entries
- [ ] Disbursement = CK − FEE
- [ ] Tests pass; no changes to existing specs
- [ ] Rubocop clean
- [ ] Code is additive and removable without impact

## Implemented

### Implemented flows

- **DepositFlow**: CI + CK − CO − FEE = PAC. Handles cash in, checks in, cash back, and fees.
- **VaultTransferFlow**: Debit destination, credit source. Same amount each side.
- **WithdrawalFlow**: CO + FEE = PAD. Cash out + fee = debit from primary.
- **TransferFlow**: CAC + FEE = PAD. Amount to counterparty + fee = debit from primary.
- **CheckCashingFlow**: CK = CO + FEE. Disbursement = CK − FEE.
- **MiscReceiptFlow**: FEE = CI + CK + PAD. Income credit funded by cash, checks, or account.
- **DraftFlow**: BD + FEE = Total Due, CI + CK + PAD = Payments.
- **BillPaymentFlow**: BP + FEE = Total Due, CI + CK + PAD = Payments.
- **PartBuilder** dispatches to all flow types.

### Parts GUI (Option A — separate routes)

- **Routes** under `namespace :teller` / `namespace :parts`:
  - `GET /teller/parts` — Parts landing page (Overview)
  - `/teller/parts/deposits/new`, `POST /teller/parts/deposits`
  - `/teller/parts/vault_transfers/new`, `POST /teller/parts/vault_transfers`
  - `/teller/parts/withdrawals/new`, `POST /teller/parts/withdrawals`
  - `/teller/parts/transfers/new`, `POST /teller/parts/transfers`
  - `/teller/parts/check_cashings/new`, `POST /teller/parts/check_cashings`
  - `/teller/parts/drafts/new`, `POST /teller/parts/drafts`
  - `/teller/parts/misc_receipts/new`, `POST /teller/parts/misc_receipts`
  - `/teller/parts/bill_payments/new`, `POST /teller/parts/bill_payments`
- **Navigation:** “Parts (test)” dropdown in the teller command bar links to Overview and each flow.
- **Controllers** in `app/controllers/teller/parts/` use **PartBuilder** instead of RecipeBuilder.
- **PartsPostingExecution** concern overrides posting logic to use PartBuilder; metadata and Engine integration unchanged.
- Pages show a “(Parts)” label to distinguish from the main teller flows.

### Rake task

- `rake parts:print_legs FLOW=check_cashing|withdrawal|transfer|deposit|vault_transfer|misc_receipt|draft|bill_payment` supported.
- Optional env: `CASH_BACK_CENTS`, `SOURCE_REF`, `DEST_REF`, `FEE_CENTS`, `CHECK_ITEMS`, `AMOUNT_CENTS`, etc.

---

## Out of Scope (for PoC)

- Controller integration (Parts GUI is implemented as test/parallel path; main flows still use recipes)
- Feature flags
- Non-teller flows
- Migration of other flows to PartBuilder

---

## Appendix: Current vs. Part Model (Check Cashing)

### Current (main)

- Recipe: `CheckCashingRecipe` with `fee_cents`, `net_cash_payout_cents`
- Form: `fee_cents` field (withheld from payout)

### Current (fee-refactor branch)

- Legacy fee removed
- `net_cash_payout = check_amount`; no withheld fee
- Fees via misc_additions (debit from primary account)

### Part Model (PoC)

- Equation: CK = CO + FEE
- Disbursement (CO) = CK − FEE
- No primary account required for fee
- Matches the original "withheld" semantics
