# BankCORE — Phase 1 Implementation Status (Snapshot)

**As of:** 2026-02-22  
**Scope authority:** [docs/10_phase1_spec.md](docs/10_phase1_spec.md)  

This document is **non-authoritative** and exists only to track implementation progress against the authoritative Phase 1 specification.

---

## 3.1 Teller environment and session lifecycle

- [x] Set teller context (branch + workstation)
- [x] Open teller session
- [x] Assign drawer for the session
- [ ] Change drawer for the session (release prior assignment; track lifecycle)
- [x] Enforce prerequisites before posting (open session + assigned drawer)
- [x] Enforce prerequisites precisely as specified: **block cash-affecting postings** when no drawer is assigned
- [ ] Close teller session captures minimal balancing:
  - [x] declared cash
  - [x] expected cash
  - [x] variance
  - [x] variance reason/notes

## 3.2 Teller transaction types

### Core transactions

- [x] Deposit
  - [x] Supports cash and 0..N check line items
  - [x] Captures optional hold metadata (non-destructive) end-to-end (UI → request → persistence)
- [x] Withdrawal (cash-only)
- [x] Transfer (account-to-account)

### Expanded transactions

- [ ] Draft issuance
- [x] Check cashing
- [ ] Vault transfer (drawer <-> vault)

---

## 3.3 Teller workstation UX requirements

- [x] Transaction entry shell separates Entry (editable) vs Reference panel (read-only) vs Totals/balance
- [x] Real-time totals and out-of-balance indicators while entering
- [x] Cash source (drawer) is visible in context and not editable per-transaction
- [x] Server enforces drawer-derived cash leg for deposit/withdrawal
- [x] Receipt/audit view for posted transactions (a dedicated view/page rendering context + legs)
- [x] Transaction history list with receipt drilldown for posted transactions

## 3.4 Supervisory approvals (Phase 1)

- [x] Non-destructive prompt when approval is required
- [x] Supervisor credential validation + token issuance endpoint
- [x] Posting requires/validates approval token when required
- [x] Approval capture records “policy trigger” metadata beyond a generic threshold reason (richer audit trail)

---

## 5) Acceptance criteria (testable)

### 5.1 Posting integrity

- [x] Persisted posting package (batch + legs) exists for each posted transaction
- [x] Balanced legs enforced
- [x] Request/correlation id recorded
- [x] Actor + teller session + branch + workstation attribution recorded
- [x] Idempotency: duplicate request ids are handled safely

### 5.2 Cash control

- [x] Cash-affecting transactions cannot post unless session open + drawer assigned
- [x] Deposit/withdrawal cash leg derived from assigned drawer; client override ignored
- [x] CashMovement amount reflects **cash** component only (for deposits with checks)

### 5.3 Deposit (cash + checks)

- [x] Supports n ≥ 0 checks
- [x] Displays cash subtotal, check subtotal, effective total
- [x] Blocks posting when out-of-balance
- [x] Hold metadata captured/persisted without breaking balancing

### 5.4 Withdrawal (cash-only)

- [x] Supports cash-only withdrawal
- [x] Displays net cash movement and projected drawer impact
- [x] Blocks posting when prerequisites are missing or out-of-balance

### 5.5 Transfer

- [x] Requires from/to account references
- [x] Produces balanced legs
- [x] Confirm drawer prerequisite behavior matches spec (transfer does not require drawer)

### 5.7 Receipt / audit

- [x] Posted transaction is viewable in receipt/audit-friendly format:
  - [x] context (teller/session/drawer/branch/workstation)
  - [x] transaction type and references
  - [x] posting legs summary
  - [x] timestamps and correlation/request id

### 5.9 Transaction history / drilldown

- [x] Teller can view a chronological list of recent posted transactions
- [x] Each history row links to existing receipt/audit detail view
- [x] History list is scoped to current teller + branch/workstation context

### 5.8 Close-out

- [x] Session can be closed
- [x] Closing captures declared cash AND produces variance calculation
- [x] Close-out creates an auditable record including variance and notes

---

## Decisions / follow-ups

- **Transfer vs drawer prerequisite:** Current implementation blocks all teller postings unless a drawer is assigned. Spec says “cash-affecting postings” must be blocked; decide whether Transfer should be allowed without a drawer.
  - **Decision:** Block only cash-affecting postings.
- **Deposit cash movement vs checks:** Confirm whether `CashMovement` should represent only physical cash in/out (typical) rather than effective deposit total.
  - **Decision:** `CashMovement` only affects physical cash in/out.
- **Hold metadata:** Decide where hold data lives (posting metadata, check instrument table, or dedicated hold record) and how it impacts available vs ledger.
  - **Decision:** Hold data lives in posting metadata.
