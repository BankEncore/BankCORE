---
status: considering
category: considering
updated: 2026-03-01
---

## Teller Module MVP (Phase 1\) — CONCEPTUAL

> **Note:** This document is conceptual UX/workflow guidance.
> The authoritative Phase 1 scope and acceptance criteria are in: [10_phase1_spec.md](../current/10_phase1_spec.md).

This MVP is the smallest feature set that yields a usable teller workstation with audit-grade posting integrity, while keeping CIF/accounts/GL minimal.

---

# 1\) MVP outcome (what “done” means)

A teller can:

* open a teller session and be assigned a drawer  
* perform core teller transactions (Deposit, Withdrawal, Transfer, Draft, Check Cashing, Vault Transfer)  
* see real-time totals / out-of-balance indicators while entering a transaction  
* get non-destructive prompts for supervisor approval when required  
* post transactions that generate **balanced posting legs** and persist an immutable posting package  
* view a receipt/audit view of what posted  
* view account history (what affected the account)  
* close a teller session with minimal balancing capture

---

# 2\) MVP user roles (minimum)

* **Teller**: perform transactions within assigned drawer/session  
* **Supervisor**: approve overrides, optionally do teller work  
* **Admin**: configuration \+ user role assignment  
* (Optional) **Auditor read-only**: view posted history/audit

---

# 3\) MVP workflows

## A) Start-of-day

1. Teller logs in  
2. Selects branch/workstation (or is pre-bound)  
3. Opens teller session  
4. Assigns drawer (cash location)

**Acceptance criteria**

* cannot post cash transactions without an open session \+ assigned drawer  
* session context visible consistently in UI

---

## B) Deposit (cash \+ unlimited checks)

* select account  
* dynamic reference panel (balances, status, alerts)  
* enter cash amount  
* add N check items via “Add check” (no preallocated rows)  
* optional hold fields per check (expandable)  
* live totals (cash subtotal, checks subtotal, total deposit)  
* post → receipt

**Acceptance criteria**

* supports 0..N checks  
* hold info captured but does not break balancing  
* posts balanced legs \+ cash movement (for cash-in)  
* “out of balance” blocks post

---

## C) Withdrawal (cash-only, then mixed)

* select funding account  
* reference panel updates  
* enter cash-out amount  
* live cash impact \+ availability check

**MVP acceptance criteria**

* cash-only withdrawal supported end-to-end  
* NSF behavior (policy): either reject or require supervisor approval (recommended: approval-gated)  
* posts balanced legs \+ cash movement

**Stretch within Phase 1**

* mixed disbursement: cash \+ official check \+ fee

---

## D) Transfer (account → account)

* select “From” and “To” accounts  
* dual reference panels  
* enter amount  
* live validation (cannot transfer to same acct unless allowed)

**Acceptance criteria**

* balanced legs only (no cash movement)  
* NSF/blocked accounts handled via policy (reject or approval)

---

## E) Draft issuance (official check)

* choose funding source: account or cash  
* enter payee \+ amount  
* optional fee  
* post → official check record created \+ receipt

**Acceptance criteria**

* posts liability leg (`OFFICIAL_CHECKS_OUTSTANDING`)  
* issues instrument with unique number (minimal allocator)  
* fee posting supported (fixed fee v1)

---

## F) Non-customer check cashing (high control risk)

* capture ID verification (required by policy/threshold)  
* enter check item (routing/check\#/amount/category)  
* fee withheld (optional)  
* net cash out displayed clearly  
* supervisor approval prompt when policy triggers

**Acceptance criteria**

* legs hit `CHECKS_IN_PROCESS` and cashbox and fee income  
* ID gating enforced  
* approval prompt does not clear transaction

---

## G) Vault transfer (drawer ↔ vault)

* move cash between cash locations (per permissions)  
* posts balanced cash-location legs \+ cash movements

**Acceptance criteria**

* restricted by permission  
* requires open session  
* produces no customer account impact

---

## H) Receipts / audit view

For every posted teller transaction:

* show summary \+ totals  
* show posting legs (debit/credit) in a compact ledger table  
* show cash movements, instruments, approvals used  
* provide stable reference id (posting batch id)

**Acceptance criteria**

* any posting batch can be traced from UI to persisted legs

---

## I) Account history (ledger view)

* show chronological list of impacts on an account  
* link each row to teller transaction receipt

**Acceptance criteria**

* backed by `account_transactions` (or posting legs query)  
* consistent ordering by effective\_at \+ posting ids

---

## J) End-of-day session close (minimal)

* teller closes session  
* enters declared cash count (single number v1)  
* system shows expected cash (derived from cash movements) and variance

**Acceptance criteria**

* session cannot close if there are unposted drafts (optional rule)  
* variance stored for audit

---

# 4\) MVP UI/UX standards (minimum)

## A) Transaction shell (consistent layout)

* left: data entry  
* right: reference panel(s)  
* bottom: totals \+ balance indicator \+ post button  
* modal: approvals (supervisor credentials) \+ reason displayed

## B) Real-time feedback

* totals update on every change  
* clear “out of balance” indicator (blocks post)  
* warnings vs errors are visually distinct  
* approval-required is distinct from error

## C) Progressive disclosure

* add check line-items on demand  
* optional fields collapsed (hold date, ID details extensions, memo)

---

# 5\) MVP posting guarantees (system invariants)

* all posting goes through `Posting::Engine`  
    
* every posting batch balanced (`Σdebits == Σcredits`)  
    
* all posted legs immutable  
    
* every posting has traceability:  
    
  * request\_id, teller\_session\_id, teller\_transaction\_id  
  * component\_index references


* approvals are recorded and linked to posting batch  
    
* idempotency enforced for teller `request_id`

---

# 6\) MVP policies (minimal configuration)

* cash threshold → needs approval  
    
* check cashing threshold → needs approval  
    
* ID required for non-customer check cashing (always or threshold-based)  
    
* NSF policy:  
    
  * reject vs needs approval (recommend: needs approval)


* account alert severities:  
    
  * block posting  
  * requires approval  
  * informational

---

# 7\) MVP reporting outputs (Phase 1\)

* teller session activity list \+ totals  
* basic drawer cash expected vs declared  
* account history view  
* audit log entries for: posting attempts, approvals, session open/close

---

## Teller Module MVP (Phase 1\) — CONCEPTUAL

This MVP is the smallest feature set that yields a usable teller workstation with audit-grade posting integrity, while keeping CIF/accounts/GL minimal.

---

# 1\) MVP outcome (what “done” means)

A teller can:

* open a teller session and be assigned a drawer  
* perform core teller transactions (Deposit, Withdrawal, Transfer, Draft, Check Cashing, Vault Transfer)  
* see real-time totals / out-of-balance indicators while entering a transaction  
* get non-destructive prompts for supervisor approval when required  
* post transactions that generate **balanced posting legs** and persist an immutable posting package  
* view a receipt/audit view of what posted  
* view account history (what affected the account)  
* close a teller session with minimal balancing capture

---

# 2\) MVP user roles (minimum)

* **Teller**: perform transactions within assigned drawer/session  
* **Supervisor**: approve overrides, optionally do teller work  
* **Admin**: configuration \+ user role assignment  
* (Optional) **Auditor read-only**: view posted history/audit

---

# 3\) MVP workflows

## A) Start-of-day

1. Teller logs in  
2. Selects branch/workstation (or is pre-bound)  
3. Opens teller session  
4. Assigns drawer (cash location)

**Acceptance criteria**

* cannot post cash transactions without an open session \+ assigned drawer  
* session context visible consistently in UI

---

## B) Deposit (cash \+ unlimited checks)

* select account  
* dynamic reference panel (balances, status, alerts)  
* enter cash amount  
* add N check items via “Add check” (no preallocated rows)  
* optional hold fields per check (expandable)  
* live totals (cash subtotal, checks subtotal, total deposit)  
* post → receipt

**Acceptance criteria**

* supports 0..N checks  
* hold info captured but does not break balancing  
* posts balanced legs \+ cash movement (for cash-in)  
* “out of balance” blocks post

---

## C) Withdrawal (cash-only, then mixed)

* select funding account  
* reference panel updates  
* enter cash-out amount  
* live cash impact \+ availability check

**MVP acceptance criteria**

* cash-only withdrawal supported end-to-end  
* NSF behavior (policy): either reject or require supervisor approval (recommended: approval-gated)  
* posts balanced legs \+ cash movement

**Stretch within Phase 1**

* mixed disbursement: cash \+ official check \+ fee

---

## D) Transfer (account → account)

* select “From” and “To” accounts  
* dual reference panels  
* enter amount  
* live validation (cannot transfer to same acct unless allowed)

**Acceptance criteria**

* balanced legs only (no cash movement)  
* NSF/blocked accounts handled via policy (reject or approval)

---

## E) Draft issuance (official check)

* choose funding source: account or cash  
* enter payee \+ amount  
* optional fee  
* post → official check record created \+ receipt

**Acceptance criteria**

* posts liability leg (`OFFICIAL_CHECKS_OUTSTANDING`)  
* issues instrument with unique number (minimal allocator)  
* fee posting supported (fixed fee v1)

---

## F) Non-customer check cashing (high control risk)

* capture ID verification (required by policy/threshold)  
* enter check item (routing/check\#/amount/category)  
* fee withheld (optional)  
* net cash out displayed clearly  
* supervisor approval prompt when policy triggers

**Acceptance criteria**

* legs hit `CHECKS_IN_PROCESS` and cashbox and fee income  
* ID gating enforced  
* approval prompt does not clear transaction

---

## G) Vault transfer (drawer ↔ vault)

* move cash between cash locations (per permissions)  
* posts balanced cash-location legs \+ cash movements

**Acceptance criteria**

* restricted by permission  
* requires open session  
* produces no customer account impact

---

## H) Receipts / audit view

For every posted teller transaction:

* show summary \+ totals  
* show posting legs (debit/credit) in a compact ledger table  
* show cash movements, instruments, approvals used  
* provide stable reference id (posting batch id)

**Acceptance criteria**

* any posting batch can be traced from UI to persisted legs

---

## I) Account history (ledger view)

* show chronological list of impacts on an account  
* link each row to teller transaction receipt

**Acceptance criteria**

* backed by `account_transactions` (or posting legs query)  
* consistent ordering by effective\_at \+ posting ids

---

## J) End-of-day session close (minimal)

* teller closes session  
* enters declared cash count (single number v1)  
* system shows expected cash (derived from cash movements) and variance

**Acceptance criteria**

* session cannot close if there are unposted drafts (optional rule)  
* variance stored for audit

---

# 4\) MVP UI/UX standards (minimum)

## A) Transaction shell (consistent layout)

* left: data entry  
* right: reference panel(s)  
* bottom: totals \+ balance indicator \+ post button  
* modal: approvals (supervisor credentials) \+ reason displayed

## B) Real-time feedback

* totals update on every change  
* clear “out of balance” indicator (blocks post)  
* warnings vs errors are visually distinct  
* approval-required is distinct from error

## C) Progressive disclosure

* add check line-items on demand  
* optional fields collapsed (hold date, ID details extensions, memo)

---

# 5\) MVP posting guarantees (system invariants)

* all posting goes through `Posting::Engine`  
    
* every posting batch balanced (`Σdebits == Σcredits`)  
    
* all posted legs immutable  
    
* every posting has traceability:  
    
  * request\_id, teller\_session\_id, teller\_transaction\_id  
  * component\_index references


* approvals are recorded and linked to posting batch  
    
* idempotency enforced for teller `request_id`

---

# 6\) MVP policies (minimal configuration)

* cash threshold → needs approval  
    
* check cashing threshold → needs approval  
    
* ID required for non-customer check cashing (always or threshold-based)  
    
* NSF policy:  
    
  * reject vs needs approval (recommend: needs approval)


* account alert severities:  
    
  * block posting  
  * requires approval  
  * informational

---

# 7\) MVP reporting outputs (Phase 1\)

* teller session activity list \+ totals  
* basic drawer cash expected vs declared  
* account history view  
* audit log entries for: posting attempts, approvals, session open/close

---

## Optional: MVP “cut line” (if you need to go even smaller)

**Keep:** Session \+ drawer \+ Deposit \+ Withdrawal (cash-only) \+ Transfer \+ approvals \+ receipts \+ posting engine **Defer:** Draft issuance, check cashing, vault transfer

