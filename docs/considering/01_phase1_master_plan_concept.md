---
status: considering
category: considering
updated: 2026-03-01
---

# BANKCORE

# Phase 1 Master Plan

# Teller Operations Module (MVP)

> **Note:** This is a planning/governance document.
> The authoritative Phase 1 scope and acceptance criteria are in: [10_phase1_spec.md](../current/10_phase1_spec.md).

---

# 1\. Purpose

Phase 1 establishes a production-grade Teller Operations module that:

* Processes front-counter financial transactions  
* Enforces double-entry accounting integrity  
* Maintains cash drawer accountability  
* Supports supervisory approval gating  
* Preserves full audit traceability  
* Operates independently of a full GL subsystem

Phase 1 does **not** implement full CIF maintenance or general ledger accounting.

---

# 2\. Phase 1 Scope Definition (Superseded by `docs/10_phase1_spec.md`)

## 2.1 In Scope (Phase 1A – Core Teller)

1. Teller session lifecycle  
2. Cash drawer assignment  
3. Deposit (cash \+ checks)  
4. Withdrawal (cash-only)  
5. Transfer (account-to-account)  
6. Supervisor approval workflow  
7. Posting engine with atomic commit  
8. Account history view  
9. Teller session reconciliation (minimal)  
10. Role-based access control  
11. Audit logging

## 2.2 Phase 1B (Optional Within Phase 1 Window)

1. Official check (bank draft) issuance  
2. Non-customer check cashing  
3. Vault transfer  
4. Loan payment (simple balance reduction)

If time constrained, Phase 1A is sufficient for MVP certification.

---

# 3\. Core Architectural Principles

## 3.1 Teller Transaction vs Posting Separation

* **TellerTransaction** \= operational container (UI workflow)  
* **PostingBatch** \= financial commit unit  
* **PostingLeg** \= atomic debit/credit unit

All financial truth resides in PostingLeg.

---

## 3.2 Atomic Commit Boundary

A successful transaction must persist, in one database transaction:

* TellerTransaction  
* PostingBatch  
* PostingLegs  
* CashMovements (if applicable)  
* InstrumentEffects (if applicable)  
* AccountTransactions (materialized ledger slice)  
* Account balance updates  
* ApprovalEvent (if used)  
* AuditEvent

If any component fails, nothing persists.

---

## 3.3 Balancing Invariant

For every PostingBatch:

```
Σ(debits) == Σ(credits)
```

Validation is mandatory and enforced before commit.

---

## 3.4 Immutability Rule

Posted financial records (PostingBatch, PostingLeg, AccountTransaction):

* Cannot be edited  
* Cannot be deleted  
* May only be corrected by a new reversing transaction (Phase 2+)

---

# 4\. Domain Model (Phase 1 Minimal)

## 4.1 Operational Domain

* User (Devise)  
* Role / Permission (RBAC)  
* Branch  
* Workstation  
* TellerSession  
* CashLocation (drawer, vault)

## 4.2 Customer / Account Domain (Minimal Slice)

* Party (minimal)  
    
* Account  
    
  * account\_type  
  * ledger\_balance\_cents  
  * available\_balance\_cents  
  * status


* RecordAlert (block, approval\_required, informational)

## 4.3 Posting Domain

* TellerTransaction  
* PostingBatch  
* PostingLeg  
* CashMovement  
* AccountTransaction  
* ApprovalEvent  
* AuditEvent

## 4.4 Instruments (Phase 1B)

* OfficialCheck  
* CheckItem

---

# 5\. Posting Engine Model

## 5.1 Processing Stages

1. BuildRequest  
2. Normalize  
3. Validate  
4. ApplyPolicy  
5. GenerateLegs (Recipe)  
6. BalanceCheck  
7. Commit (atomic DB transaction)

---

## 5.2 Validation vs Policy Boundary

* Validation enforces structural correctness (balances, existence, session open, etc.)  
    
* Policy determines:  
    
  * Reject  
  * Require supervisor approval  
  * Allow

Example:

* NSF → policy determines reject vs approval  
* Cash threshold → policy determines approval required

---

# 6\. Account Balance Authority

Phase 1 defines:

* Account balances are updated synchronously during Posting::Commit  
* Ledger balance is authoritative  
* Running balances in AccountTransaction are derivative  
* System supports deterministic rebuild from PostingLeg if needed

---

# 7\. Currency Model

* Phase 1 supports USD only  
* All PostingBatch entries must share currency  
* Balancing occurs per currency

---

# 8\. Teller Workflows (Phase 1A)

## 8.1 Session Lifecycle

* Open session (requires permission)  
    
* Assign drawer  
    
* Perform transactions  
    
* Close session  
    
  * Capture declared cash  
  * Compute expected cash:

```
Expected = Opening Cash
         + Σ cash_in
         - Σ cash_out
         ± Σ vault_moves
```

---

## 8.2 Deposit

Supports:

* Cash  
* Unlimited checks  
* Optional hold metadata per check

Posting examples:

Cash Deposit:

* DR CashLocation  
* CR Account

Check Deposit:

* DR CHECKS\_IN\_PROCESS  
* CR Account

---

## 8.3 Withdrawal (Cash Only)

* DR Account  
* CR CashLocation

NSF handled via policy.

---

## 8.4 Transfer

* DR From Account  
* CR To Account

No cash movement.

---

# 9\. Phase 1B Transactions

## 9.1 Official Check

Funded by:

* Account OR  
* Cash

Posts:

* CR OFFICIAL\_CHECKS\_OUTSTANDING

---

## 9.2 Non-Customer Check Cashing

* DR CHECKS\_IN\_PROCESS  
* CR CashLocation  
* Optional CR FeeIncome

Requires:

* ID verification (policy-based)  
* Threshold gating

---

## 9.3 Vault Transfer

* DR Vault  
* CR Drawer

No customer impact.

---

# 10\. Approval Model

## 10.1 Behavior

If policy returns `needs_approval`:

* No posting occurs  
* Transaction state preserved  
* Supervisor prompt displayed  
* ApprovalEvent recorded  
* Posting reattempted

Approval is non-destructive.

---

# 11\. UI/UX Standards (Minimum)

## 11.1 Transaction Shell Layout

* Entry panel (left)  
* Reference panel (right)  
* Totals \+ balance indicator (bottom)  
* Approval modal (overlay)

## 11.2 Real-Time Behavior

* Totals update dynamically  
* Out-of-balance disables Post  
* Approval-required visually distinct from error  
* Progressive disclosure for optional fields

---

# 12\. Access Control Model

* Devise: authentication  
* Pundit: authorization  
* RBAC with scoped roles (branch/workstation)  
* Permissions defined by capability  
* No controller-level role conditionals

---

# 13\. Audit Requirements

System logs:

* Session open/close  
* Posting attempts (success or failure)  
* Approval events  
* Transaction commits

Audit records must include:

* actor\_user\_id  
* branch\_id  
* workstation\_id  
* teller\_session\_id  
* posting\_batch\_id (if applicable)  
* timestamp

---

# 14\. Acceptance Criteria (Certification Standard)

Phase 1 is complete when:

* All transactions route exclusively through Posting::Engine  
* All posting batches balance  
* No financial record is mutable  
* Approval gating is enforced  
* Cash reconciliation computes correctly  
* Role permissions block unauthorized actions  
* Account history view reflects ledger truth

---

# 15\. Explicit Out of Scope

Phase 1 does NOT include:

* Full CIF maintenance  
* Multi-party account ownership modeling  
* Interest accrual  
* Overdraft protection logic  
* ACH / external EFT  
* GL journaling subsystem  
* Reversal model (defined but implemented in Phase 2\)  
* Multi-currency support

---

# 16\. Forward Compatibility Guarantees

Phase 1 architecture supports:

* Addition of GL mapping layer  
* Reversal transactions  
* Multi-channel posting (ATM, online)  
* Advanced policy rules  
* Multi-currency expansion  
* Loan amortization logic  
* Advanced instrument lifecycle management

No Phase 1 design decision should block these expansions.
