# BankCORE — Phase 1

# Developer Implementation Roadmap (Sprint-Structured)

> **Note:** This document is an implementation sequencing roadmap.
> It must remain consistent with: `docs/10_phase1_spec.md`.

This roadmap translates the Phase 1 Master Plan into an actionable engineering sequence.

Assumptions:

* Rails 8.1  
* MariaDB  
* Devise (authentication)  
* Pundit (authorization)  
* TailwindCSS \+ DaisyUI  
* Turbo \+ Stimulus  
* Posting::Engine as central financial authority

This roadmap assumes 2-week sprints. Adjust cadence as needed.

---

# Sprint 0 — Foundation & Environment

## Objectives

Establish project scaffolding and guardrails before any financial logic is written.

## Deliverables

### 1\. Rails Setup

* Authentication enabled  
* Pundit installed  
* Current attributes pattern (`Current.branch`, `Current.workstation`, `Current.teller_session`)

### 2\. Core Context Models

* Branch  
* Workstation  
* User  
* Role / Permission / UserRole (scoped)  
* Seed baseline roles \+ permissions

### 3\. Authorization Infrastructure

* ApplicationPolicy  
* `User#has_permission?`  
* Pundit rescue handling  
* Enforced `authenticate_user!`

### 4\. Basic Layout

* Application shell  
* Session context banner  
* Navigation placeholders  
* Standardized UI panel layout

### Exit Criteria

* Users can log in  
* Roles enforce screen access  
* No business logic implemented yet

---

# Sprint 1 — Teller Session & Cash Control

## Objectives

Enable operational environment: teller session lifecycle and drawer accountability.

## Deliverables

### 1\. Cash Models

* CashLocation (drawer, vault)  
* TellerSession  
* CashLocationAssignment

### 2\. Teller Session Workflow

* Open session screen  
* Assign drawer  
* Close session (minimal version)

### 3\. Session Constraints

* Cannot post without open session  
* Cannot post without assigned drawer

### 4\. Basic Audit Logging

* AuditEvent model  
* Log session open/close

### Exit Criteria

* Teller can open/close session  
* Drawer assignment enforced  
* Session context visible globally

---

# Sprint 2 — Posting Engine Backbone

## Objectives

Build financial core before any UI-heavy transaction work.

## Deliverables

### 1\. Posting Models

* TellerTransaction  
* PostingBatch  
* PostingLeg  
* CashMovement  
* AccountTransaction

### 2\. Posting::Engine Skeleton

Pipeline stages:

* BuildRequest  
* Validate  
* ApplyPolicy  
* GenerateLegs  
* BalanceCheck  
* Commit

### 3\. Atomic DB Transaction Wrapper

Single transaction boundary for commit stage.

### 4\. Balancing Enforcement

Σ debits \== Σ credits validation

### 5\. Idempotency

* request\_id uniqueness enforcement

### 6\. Account Balance Update

* ledger\_balance\_cents updated in commit stage

### Exit Criteria

* Engine can process a hard-coded test transaction  
* Balanced invariant enforced  
* Account balance updates correctly  
* No financial records editable

---

# Sprint 3 — Deposit Workflow (End-to-End)

## Objectives

Implement first real transaction type fully through engine.

## Deliverables

### 1\. Deposit Recipe

* Cash component  
* Check component (multiple allowed)  
* Optional hold metadata

### 2\. Deposit UI

* Account selector  
* Dynamic reference panel  
* “Add Check” button  
* Real-time totals  
* Balance indicator

### 3\. Deposit Validation Endpoint

* Live total recalculation  
* Policy pre-check

### 4\. Receipt View

* Summary  
* Posting legs table  
* Cash movements

### Exit Criteria

* Deposit posts through engine  
* Multiple checks supported  
* Out-of-balance blocked  
* Receipt view traceable to PostingBatch

---

# Sprint 4 — Withdrawal & Transfer

## Objectives

Add second and third transaction types.

---

## A) Withdrawal (Cash-Only)

### Deliverables

* Withdrawal recipe  
* NSF validation  
* Policy gating (reject vs approval)  
* Cash movement recording

---

## B) Transfer

### Deliverables

* Dual account reference panels  
* Transfer recipe  
* Same-account validation  
* No cash movement

---

### Exit Criteria

* Withdrawal and transfer fully functional  
* Approval flow can trigger  
* All posting through engine

---

# Sprint 5 — Approval System

## Objectives

Implement supervisor override gating.

---

## Deliverables

### 1\. ApprovalEvent Model

* Links to PostingBatch or TellerTransaction  
* Records supervisor user

### 2\. Engine Behavior

If policy returns `needs_approval`:

* No commit  
* Return structured response

### 3\. UI Modal

* Supervisor credential entry  
* Non-destructive retry  
* ApprovalEvent recorded

### 4\. Authorization Enforcement

* `approvals.override.execute` required

---

### Exit Criteria

* Threshold-triggered transactions require approval  
* Approval does not clear transaction  
* Approved retry posts successfully

---

# Sprint 6 — Account History & Reconciliation

## Objectives

Provide ledger transparency and session reconciliation.

---

## A) Account History

* AccountTransaction view  
* Chronological ordering  
* Link to receipt

---

## B) Teller Session Activity

* List of TellerTransactions for session  
* Totals summary

---

## C) Session Close Reconciliation

Expected cash formula:

```
Expected = Opening
         + Σ cash_in
         - Σ cash_out
         ± Σ vault_moves
```

* Capture declared cash  
* Compute variance

---

### Exit Criteria

* Account history accurate  
* Session reconciliation matches cash movements

---

# Sprint 7 (Optional Phase 1B)

## Official Check (Draft)

* OfficialCheck model  
* Number allocator  
* Recipe  
* Receipt extension

## Non-Customer Check Cashing

* CheckItem model  
* ID verification capture  
* Threshold gating

## Vault Transfer

* Recipe  
* Permission enforcement

---

# Cross-Sprint Standards

These are continuous and must be enforced every sprint.

---

## 1\. All Financial Posting Goes Through Posting::Engine

No controller may directly create PostingLeg.

---

## 2\. Immutability

No update/delete allowed on:

* PostingBatch  
* PostingLeg  
* AccountTransaction

---

## 3\. Test Harness

Each recipe must have:

* Table-driven test  
* Balanced invariant test  
* Approval gating test  
* Idempotency test

---

## 4\. Audit Logging

Log:

* Posting attempt  
* Approval  
* Commit  
* Session open/close

---

# Suggested Sprint Order (Critical Path)

1. Sprint 0 — Auth & roles  
2. Sprint 1 — Session/drawer  
3. Sprint 2 — Posting engine  
4. Sprint 3 — Deposit  
5. Sprint 4 — Withdrawal/Transfer  
6. Sprint 5 — Approvals  
7. Sprint 6 — History & reconciliation  
8. Sprint 7 — Optional instruments

---

# Risk Controls (Developer Awareness)

| Risk | Control |
| :---- | :---- |
| Double-posting | request\_id idempotency |
| Out-of-balance posting | BalanceCheck hard fail |
| Unauthorized posting | Pundit in controller |
| Approval bypass | Engine enforces gating |
| Data tampering | Immutable posting tables |
| Cash mismatch | Deterministic reconciliation formula |

---

# Phase 1 Completion Definition

Phase 1 is complete when:

* Core teller workflows operate end-to-end  
* All financial activity is immutable and balanced  
* Approval gating functions correctly  
* Drawer reconciliation is accurate  
* Authorization model enforced  
* Audit logging present  
* No financial bypass paths exist
