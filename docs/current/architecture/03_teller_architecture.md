---
status: current
category: current
updated: 2026-03-01
---

# BankCORE – Iteration 1 (Teller-Focused Architecture)

> **Note:** This document describes architecture direction and domain boundaries.
> Phase 1 scope and acceptance criteria are defined in: [10_phase1_spec.md](../10_phase1_spec.md).

## Foundational Principle

Teller is an operational event engine. CIF, Accounts, and GL are controlled reference domains it touches — but does not own.

---

# 1️⃣ Core System Domains (v1 Scope)

## A. Identity Domain (Minimal CIF Layer)

Purpose: Identify who is transacting.

### Owns:

* `parties`  
* `alerts`  
* minimal KYC flags  
* OFAC screening status (basic)

### Does NOT Own (yet):

* Full onboarding workflows  
* Risk scoring engines  
* Relationship hierarchies

Teller only needs:

* Identity resolution  
* Alert lookup  
* Basic eligibility checks

---

## B. Account Domain (Minimal Account Ledger Layer)

Purpose: Maintain balances and allow postings.

### Owns:

* `accounts`  
* `account_parties`  
* `account_balances`  
* `account_postings`

### Teller interacts by:

* Creating posting legs  
* Requesting balance validation  
* Respecting holds/restrictions

Teller does NOT:

* Recalculate balances directly  
* Define product behavior  
* Own interest accrual logic

---

## C. Teller Domain (Primary v1 Focus)

Purpose: Operational event engine \+ cash control.

### Owns:

* `teller_sessions`  
* `teller_drawers`  
* `teller_transactions`  
* `posting_legs`  
* `cash_movements`  
* `instrument_records`  
* `approval_events`

This is your core engine.

---

## D. Cash Control Domain

Purpose: Physical accountability.

### Owns:

* Drawer balances  
* Vault balances  
* Cash transfers  
* Denomination tracking (future)

---

## E. GL Control Layer (Minimal Stub)

In v1, this should be:

* A mapping abstraction  
* Not a full general ledger

### Owns:

* `gl_accounts`  
* `gl_templates`  
* `gl_entries` (optional, may stub)

Teller posts through:

```
posting_legs → GL mapping engine → GL control entries
```

But Teller should not know GL internals.

---

# 2️⃣ Clean Separation Model

```
[ Teller Transaction ]
        ↓
[ Posting Engine ]
        ↓
[ Account Postings ]  →  Account Domain
[ Cash Movements ]    →  Cash Control
[ GL Entries ]        →  GL Layer
[ Instrument Records ]
[ Approval Records ]
```

---

# 3️⃣ What Teller Must NOT Own (Critical)

To prevent future rewrite:

* Account product definitions  
* Interest accrual logic  
* GL chart structure  
* Fee schedules (should reference external table)  
* Account restrictions logic (should consult Account Domain)

---

# 4️⃣ Iteration 1 Module Breakdown

Here is a clean modular structure:

### 1\. Identity (Lightweight CIF)

* Parties  
* Alerts  
* Identification records

### 2\. Accounts (Ledger Stub)

* Accounts  
* Account balances  
* Posting storage  
* Hold flags

### 3\. Teller Operations

* Teller sessions  
* Teller transactions  
* Posting leg generation  
* Approval workflow

### 4\. Cash & Vault

* Drawer balances  
* Vault ledger  
* Cash transfer tracking

### 5\. Instrument Control

* Official checks  
* Negotiable instrument logs

### 6\. GL Bridge (Minimal)

* GL template mapping  
* Summary entry generation

---

# 5️⃣ Critical Architectural Rule

**Teller transactions should never directly modify balances.**

They:

1. Generate posting legs  
2. Submit them to the Posting Engine  
3. The Account domain updates balances  
4. The GL layer derives entries

This ensures:

* Future real-time posting  
* Batch replay ability  
* Audit integrity  
* Rebuildable balances

---

# 6️⃣ What You Are Actually Building in v1

You are building:

A real-time balanced event engine with cash accountability.

That is different from:

* A core ledger system  
* A deposit platform  
* A GL platform

But it must integrate cleanly with all three.

---

# 7️⃣ Recommended Expansion Path

After Teller v1 stabilizes:

1. Harden Account Domain (holds, product logic)  
2. Harden GL Layer (true journal system)  
3. Expand CIF (relationship graph)  
4. Add Fee Engine  
5. Add Risk/CTR Aggregation

---

# 8️⃣ What I Recommend Next

To keep this architecturally pure, the next most important artifact is:

## A Unified Posting Engine Pattern

Because that will define:

* How teller generates legs  
* How legs are validated  
* How balancing is enforced  
* How GL mapping is abstracted  
* How future non-teller channels plug in

If you design that correctly, everything scales cleanly.
