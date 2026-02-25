# BankCORE Reporting Requirements & Capability Assessment

**Purpose:** Define reporting requirements and assess how well the current architecture supports them.

**Related:** [00_postng_architecture_250225.md](00_postng_architecture_250225.md), [12_regulatory_eval.md](12_regulatory_eval.md), [13_minimum_controls.md](13_minimum_controls.md)

---

# 1. Reporting Requirements (from docs)

## 1.1 Teller Activity Report (L7-WF-01, OPS-010)

| Requirement | Source |
|-------------|--------|
| Filters: Branch, date range, teller, workstation, session | L7-WF-01 |
| Teller summary: Sessions opened, cash in/out, drafts, checks cashed, fees, transfers, reversals, net cash | L7-WF-01 |
| Drill-down to session detail | L7-WF-01 |
| Totals reconcile with posting data | L7-WF-01 |

**Route:** `GET /ops/reports/teller_activity` (not implemented)

---

## 1.2 Session Detail (L7-WF-03, OPS-030)

| Requirement | Source |
|-------------|--------|
| Session summary: teller, branch, workstation, open/close times, opening/expected/closing cash, variance | L7-WF-03 |
| Transaction list: time, type, ref #, amount, cash impact, approved?, reversed? | L7-WF-03 |
| Approval events table | L7-WF-03 |
| Vault transfers summary | L7-WF-03 |
| Reversals paired with originals | reversals.md |

**Route:** `GET /ops/sessions/:id` (not implemented)

---

## 1.3 Regulatory / Control Reporting

| Requirement | Source |
|-------------|--------|
| Full audit traceability | 12_regulatory_eval |
| Financial audit log (posting committed, reversals, failed attempts) | 13_minimum_controls |
| Operational monitoring (duplicate attempts, failed validations, reversal frequency, cash variance) | 13_minimum_controls |
| GL mapping / reporting derivation | 00_system_charter |

---

# 2. Data Model Support (Current)

| Data Need | Source | Status |
|-----------|--------|--------|
| Teller activity by type | TellerTransaction + CashMovement | ✅ Available |
| Cash in/out by session | CashMovement (direction, amount) | ✅ Available |
| Transaction counts by type | TellerTransaction.group(:transaction_type) | ✅ Available |
| Drafts issued | TellerTransaction (type=draft) + metadata | ✅ Available |
| Checks cashed | TellerTransaction (type=check_cashing) + metadata | ✅ Available |
| Fees collected | PostingLeg / AccountTransaction (income:*) | ⚠️ Requires aggregation |
| Transfers count | TellerTransaction (type=transfer) | ✅ Available |
| Reversals | reversal_of_* link | ❌ Not implemented |
| Session open/close/variance | TellerSession | ✅ Available |
| Approval events | ApprovalEvent or similar | ⚠️ Verify existence |
| Vault transfers | TellerTransaction (type=vault_transfer) + metadata | ✅ Available |
| Full posting detail | PostingLeg, PostingBatch | ✅ Available |
| Cash impact per transaction | CashMovement | ✅ Available |

---

# 3. Current Implementation Status

## 3.1 Implemented

| Capability | Location | Notes |
|------------|----------|-------|
| Session-level movements by type | DashboardController#build_movements_by_type | Counts + cash in/out by transaction type |
| Raw journal ledger | Ops::LedgerController | Posting legs with batch info (limit 100) |
| Transaction history | Teller::TransactionHistoryController | Posted transactions for current teller/workstation |
| Recent activity | Dashboard partial | Last 10 transactions for session |
| Receipt / audit view | Teller::ReceiptsController | Posting legs, metadata, cash movements |
| Account balance / history | AccountReferenceSnapshot, _balance_and_history | Per-account ledger view |

## 3.2 Not Implemented

| Capability | Gap |
|------------|-----|
| Teller Activity Report | No route; no aggregation by branch/date/teller |
| Session search | No GET /ops/sessions with filters |
| Session detail | No GET /ops/sessions/:id |
| Reversal pairing | No reversal model; cannot show original↔reversal |
| Financial audit log | No financial_audit_events table |
| Fee aggregation | No report-level aggregation of income:* legs |
| Operational monitoring/alerts | No monitoring for duplicates, failed validations, variance thresholds |

---

# 4. Gaps for Full Reporting

## 4.1 Data Gaps

| Gap | Impact |
|-----|--------|
| No reversal model | Cannot report reversals or pair originals with reversals |
| No financial audit log | Cannot report posting events, reversals, failures for audit |
| Fees in legs only | Fee totals require summing income:* legs across batches |

## 4.2 Query / Aggregation Gaps

| Gap | Effort |
|-----|--------|
| Cross-session aggregation | New queries/scopes for branch, date range, teller |
| Fee totals | Sum AccountTransaction where account_reference LIKE 'income:%' |
| Drill-down teller → sessions | Join TellerTransaction → TellerSession |

## 4.3 UI Gaps

| Gap | Effort |
|-----|--------|
| Ops report pages | New controllers, views, filters |
| Session detail page | New controller, view |
| Reversal display | Depends on reversal model |

---

# 5. Assessment Summary

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Data model for reporting | Strong | TellerTransaction, CashMovement, PostingLeg support most needs |
| Fee reporting | Moderate | Possible via legs; no dedicated fee aggregation |
| Reversal reporting | Blocked | Reversal model not implemented |
| Ops report UI | Missing | Teller activity, session search, session detail not built |
| Audit log | Missing | No financial audit events table |
| Regulatory traceability | Partial | Immutable legs and metadata exist; no formal audit log |

---

# 6. Implementation Priorities

1. **Reversal model** — Required before reversal reporting.
2. **Financial audit log** — Required for audit and regulatory reporting.
3. **Fee aggregation** — Decide whether to aggregate income:* legs or add fee-specific structure.
4. **Ops report UI** — Teller activity report, session search, session detail.
5. **Operational monitoring** — Align with 13_minimum_controls (duplicates, failed validations, variance, reversal frequency).

---

# 7. Bottom Line

- **Data model:** Sufficient for teller activity, session detail, and cash reporting.
- **Blockers:** Reversal model and financial audit log.
- **Effort:** Mostly new controllers/views and queries; reversal model and audit log are the main schema changes.