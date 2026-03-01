---
status: considering
category: considering
updated: 2026-03-01
---

# BankCORE

## Technical UI Architecture Addendum

### Rails \+ TailwindCSS \+ DaisyUI \+ Turbo/Stimulus (Conceptual)

**Status:** Conceptual (implementation-agnostic) **Scope:** Teller transaction UI execution model and component contracts (not domain schema)

---

# 1\. Architectural Goal

Deliver teller workflows that are:

* **Stateful without reloads**  
* **Real-time responsive** (totals, indicators, projections)  
* **Non-destructive** under validation and approvals  
* **Consistent across transaction types**  
* **Deterministic** (UI preview matches posting engine)

This addendum describes a reference implementation approach using:

* Rails (server rendering)  
* Turbo (partial updates where appropriate)  
* Stimulus (client-side state orchestration)  
* TailwindCSS \+ DaisyUI (presentation primitives)

---

# 2\. Page Composition Pattern

Each teller transaction page uses a shared “transaction shell” and injects type-specific entry sections.

## 2.1 Shared Shell Responsibilities

* Render top context bar  
* Render page header and status badges  
* Provide 2-column layout (Entry / Reference)  
* Provide Live Totals panel  
* Provide Cash Impact footer  
* Provide Supervisor approval modal container

## 2.2 Page Sections

* **Entry section:** transaction-type specific fields  
* **Line items section:** dynamic repeated inputs (checks, splits)  
* **Reference panel:** read-only account/party info \+ projected balances  
* **Totals panel:** live computation display and posting gate  
* **Approval modal:** interrupt flow, persist state

---

# 3\. State Model (UI Execution)

UI state is modeled explicitly to mirror transaction lifecycle:

* `editing` (default)  
* `validating` (pre-post checks)  
* `approval_required` (interrupt)  
* `posting` (atomic submit)  
* `posted` (receipt / completion)

**Key rule:** Only the `posting` transition may submit data to create postings. Everything else is preview and gating.

---

# 4\. Client/Server Responsibility Split

## 4.1 Client-side (Stimulus)

Client-side logic is limited to:

* Dynamic line item add/remove  
* Real-time arithmetic and display (subtotals, totals, imbalance)  
* UI gating (disable Post)  
* Modal orchestration (approval prompts)  
* Projection calculation display (optional client math) **or** triggering server calculation to populate projection values

Client-side must not:

* Persist ledger state  
* Produce authoritative posting legs  
* Bypass validation rules

## 4.2 Server-side (Rails)

Server remains authoritative for:

* Account lookup & restrictions  
* Alerts retrieval  
* Approval evaluation rules  
* Posting engine execution (atomic posting)  
* Audit logging

---

# 5\. Data Flow Contract

## 5.1 In-Page Calculation Flow

1. User edits fields  
     
2. Stimulus recalculates:  
     
   * `cash_subtotal`  
   * `checks_subtotal`  
   * `fees_subtotal`  
   * `net_cash_movement`  
   * `total`  
   * `out_of_balance_amount`

   

3. UI updates:  
     
   * totals panel  
   * balance badge  
   * disable/enable Post button

   

4. Reference panel projections update:  
     
   * either locally (simple add/subtract) or via server preview call

## 5.2 Pre-Post Validation Flow

On “Post”:

1. UI enters `validating` state  
     
2. Server validation endpoint checks:  
     
   * required fields  
   * account restrictions  
   * thresholds requiring approval  
   * OFAC/ID requirements (as applicable)  
   * drawer limit warnings (as applicable)

   

3. Outcomes:  
     
   * **OK:** proceed to `posting`  
   * **Approval required:** open modal, remain in `editing`  
   * **Blocking errors:** return errors, remain in `editing`

## 5.3 Approval Flow (Non-destructive)

1. Approval required event occurs  
2. Modal prompts for supervisor credentials  
3. Server validates supervisor authentication \+ reason code  
4. UI stores approval token/metadata in hidden fields  
5. User clicks Post again (or auto-continues if permitted)  
6. Posting proceeds with approval metadata attached

---

# 6\. Recommended Endpoints (Conceptual)

Even if not all are implemented in v1, this is the clean separation.

## 6.1 Lookup / Reference

* `GET /teller/accounts/search?q=...` → list results  
* `GET /teller/accounts/:id/reference` → balances, restrictions, alerts

## 6.2 Preview / Validation

* `POST /teller/transactions/preview` → optional; returns projections, threshold warnings  
* `POST /teller/transactions/validate` → returns errors/warnings/approval\_required

## 6.3 Approval

* `POST /teller/approvals` → validates supervisor \+ returns approval token/id

## 6.4 Posting (Atomic)

* `POST /teller/:type` (e.g., deposits) → creates teller\_transaction \+ postings in one transaction block

---

# 7\. Stimulus Controller Contracts (Conceptual)

## 7.1 `teller_tx_controller` (Orchestrator)

**Responsibilities**

* Maintains `ui_state`  
* Aggregates outputs from other controllers  
* Enforces Post button gating  
* Coordinates validate → approve → post flow

**Inputs**

* Transaction type  
* Form data (serialized)  
* Outputs from totals controller  
* Reference panel updates

**Outputs**

* UI state transitions  
* Badge changes  
* Modal open/close

---

## 7.2 `line_items_controller`

**Responsibilities**

* Add/remove dynamic blocks (checks, splits, payees)  
* Emits `recalc` event after change  
* Ensures unlimited rows

**Implementation**

* Use `<template>` cloning or Turbo Frame append

---

## 7.3 `totals_controller`

**Responsibilities**

* Compute live totals/subtotals  
* Determine out-of-balance and delta  
* Update UI targets  
* Emit balance status to orchestrator

**Hard rule**

* Must match the posting engine math rules (same rounding, same sign conventions)

---

## 7.4 `reference_panel_controller`

**Responsibilities**

* Render read-only account/party context  
* Update projections on `recalc`  
* Highlight restrictions/alerts

**Projection Options**

* Client-side add/subtract for simple cases  
* Server-side preview for complex cases (holds, mixed funding sources, fees)

---

## 7.5 `approval_modal_controller`

**Responsibilities**

* Open modal with reason  
* Collect supervisor credentials  
* Call approval endpoint  
* Store `approval_id` in hidden input  
* Emit approval granted/denied events

---

# 8\. Turbo Usage Guidance

## 8.1 Appropriate Turbo Use

* Account search results in a Turbo Frame  
* Reference panel refresh in a Turbo Frame  
* Receipt rendering after posting  
* Exceptions/errors returned as partials

## 8.2 Avoid Turbo Overreach

Do not make every keystroke a server request.

Real-time totals must remain client-side, with optional server-side preview invoked:

* on account selection  
* on “Preview” click (optional)  
* on validation/post attempt

---

# 9\. Deterministic Calculation Parity

This is the most important technical requirement.

## 9.1 Parity Rule

UI preview values must match posting engine computed values.

Approaches:

* **Single source of truth**: share calculation logic in Ruby and return preview values  
* **Dual implementation**: if client computes totals, server must re-check and reject mismatches

## 9.2 Recommended Implementation

* Client computes for responsiveness  
* Server validates and returns authoritative totals at validate/post  
* UI displays server-confirmed totals when posting completes

---

# 10\. Form Modeling (Conceptual)

Each transaction form should serialize into a consistent structure that can be validated and posted.

Example structure:

* `transaction_type`  
* `account_id` (optional depending on type)  
* `party_id` (optional depending on type)  
* `line_items[]` (checks, splits)  
* `amounts` (cash\_in, cash\_out, fee)  
* `approval_id` (optional)  
* `memo` (optional)

This structure enables:

* consistent validation  
* consistent audit storage  
* consistent replay/testing

---

# 11\. Error/Warning Rendering Strategy

## 11.1 Inline Field Errors

* Show field-level errors near inputs  
* Do not clear field values

## 11.2 Banner Errors

* Use a top-of-entry `alert alert-error` for blocking errors  
* Warnings shown as `alert alert-warning` in reference panel or summary

## 11.3 Approval Required

* Indicate in header badge  
* Modal prompt appears  
* Post disabled until approval satisfied

---

# 12\. Performance Notes (Conceptual Targets)

* Client-side recalc: sub-100ms typical  
* Server-side validate: fast enough to feel instant for teller workflows  
* No full page reload for entry/validation/approval

---

# 13\. Security & Audit Considerations (UI Layer)

* Never log sensitive supervisor credentials  
* Clear modal fields after completion  
* Avoid displaying full account numbers in UI  
* Approval events must include reason codes and supervisor identity  
* UI should display “read-only” reference data clearly to prevent confusion

---

# 14\. Recommended UI Build Order

1. Shared shell \+ components (topbar/header/reference/totals/footer/modal)  
2. Deposit (cash \+ add check \+ optional hold)  
3. Withdrawal (cash-only, then mixed, then draft-only)  
4. Transfer (dual panels)  
5. Non-customer check cashing (ID \+ risk indicators)  
6. Vault transfer  
7. Exception/approval queue (optional)

---

# 15\. Acceptance Criteria (Technical)

A teller transaction page is considered compliant if:

* Entry is fully usable without reloads  
* All dynamic items use add/remove patterns  
* Totals and indicators update immediately  
* “Post” gating is correct  
* Approval prompt does not destroy state  
* Server validates and rejects mismatched totals  
* Receipt renders after successful posting
