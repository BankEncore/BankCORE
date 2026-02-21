# BankCORE

## Teller UI/UX Design Standards (Iteration 1\)

---

# 1\. Purpose

This document defines the minimum user interface and interaction standards for teller-facing workflows within BankCORE Iteration 1\.

The objective is to ensure:

* Logical transaction flow  
* Reduced operational error  
* High-speed data entry  
* Real-time feedback  
* Preservation of transaction state  
* Compliance with internal control expectations

These standards apply to all teller transaction screens.

---

# 2\. Design Philosophy

## 2.1 Transaction-Centric Layout

The UI shall be organized around a single transaction event.

Each screen must:

* Clearly indicate transaction type  
* Display transaction context (teller, session, time)  
* Separate input areas from reference information  
* Maintain a consistent visual hierarchy

---

## 2.2 Context-Aware Field Presentation

The interface shall display only fields relevant to the selected transaction type and current workflow state.

The system must:

* Suppress irrelevant inputs  
* Reveal additional fields only when triggered  
* Avoid pre-rendering unused components

Example:

* Deposit screen shows cash and “Add Check” controls.  
* Withdrawal screen does not display check entry fields.

---

## 2.3 Progressive Disclosure

Optional or conditional inputs shall be hidden until required.

Examples:

* Check hold section appears only when hold is applied.  
* Supervisor credentials appear only when override is triggered.  
* Additional line items appear only when added by the user.

---

## 2.4 Dynamic Reference Panels

When an account or party is selected, the interface must dynamically display key reference data without page reload.

Displayed data may include:

* Account title  
* Ledger balance  
* Available balance  
* Restrictions  
* Alerts

Reference data must be:

* Read-only  
* Visually distinct  
* Clearly separated from editable fields

---

# 3\. Real-Time Feedback Requirements

## 3.1 Live Calculations

The interface must update, in real time:

* Subtotals  
* Totals  
* Cash in/out amounts  
* Net transaction impact  
* Projected account balances

No manual refresh or recalculation button is permitted.

---

## 3.2 Out-of-Balance Indicators

The interface must continuously evaluate balance integrity.

If out of balance:

* A visible indicator must appear  
* Final submission must be disabled  
* The imbalance amount must be displayed

---

## 3.3 Threshold and Override Indicators

If a supervisory threshold is exceeded:

* The UI must indicate approval will be required  
* The transaction must remain editable  
* The user must not lose data

Override prompts must be modal or inline and must not clear the transaction state.

---

# 4\. Dynamic Line Entry Standards

For repeatable inputs (e.g., deposited checks):

* No fixed number of entry rows shall be pre-rendered.  
* Users shall add line items via an “Add” control.  
* Each line must be independently editable and removable.  
* Totals must update immediately when rows change.

Unlimited entries shall be supported.

---

# 5\. Transaction State Preservation

Under no circumstance shall the system:

* Clear entered data due to validation  
* Reset the transaction due to override  
* Force page reload during active entry  
* Lose dynamically added line items

All validation and approval workflows must preserve in-progress state.

---

# 6\. Visual Hierarchy & Layout

All teller screens shall follow a consistent structure:

1. Header  
     
   * Transaction type  
   * Session context

   

2. Primary Input Area  
     
   * Transaction entry fields

   

3. Reference Panel  
     
   * Account or party summary

   

4. Totals & Controls  
     
   * Real-time calculations  
   * Post/Complete button

---

# 7\. Error & Warning Differentiation

The system must distinguish between:

* Validation errors (prevent posting)  
* Warnings (advisory)  
* Supervisor-required conditions (escalation)

Each must have a distinct visual treatment.

---

# 8\. Performance Expectations

The UI must:

* Respond instantly to input changes  
* Update calculations within perceptible real-time  
* Avoid blocking interactions  
* Support keyboard-driven workflows

Teller speed and accuracy are operational requirements.

---

# 9\. Control & Compliance Alignment

These UI standards are not aesthetic preferences. They support:

* Reduced cash over/short risk  
* Prevention of posting imbalance  
* Proper escalation handling  
* Audit defensibility  
* Transaction traceability

The UI is considered part of the institution’s internal control environment.

---

# 10\. Non-Negotiable UX Requirements

1. All financial totals must update live.  
2. All imbalance conditions must be visible before posting.  
3. Overrides must not destroy transaction state.  
4. Account impact must be visible prior to completion.  
5. UI calculation logic must match posting engine logic.

---

# 11\. Architectural Alignment

The UI layer must:

* Reflect the operational transaction container model.  
* Mirror posting engine calculations.  
* Remain decoupled from ledger persistence logic.  
* Preserve deterministic outcomes.

---

# Summary

These standards define:

* Interaction behavior  
* Field visibility logic  
* Calculation feedback requirements  
* Escalation behavior  
* Control alignment

They serve as minimum UX governance for TellerCORE within BankCORE.

---

# 🏦 BankCORE — Teller Deposit Screen (Styled Wireframe Concept)

---

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ BANKCORE                                                                                │
│ Teller: T001      Session: S045      Branch: 001      03/18/2026  10:42 AM            │
└──────────────────────────────────────────────────────────────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ DEPOSIT                                                                                 │
└──────────────────────────────────────────────────────────────────────────────────────────┘


┌───────────────────────────────────────────────┬──────────────────────────────────────────┐
│ TRANSACTION ENTRY                            │ ACCOUNT REFERENCE                        │
│                                               │ (Read-Only Panel)                        │
│ Account                                       │                                          │
│ ┌─────────────────────────────────────────┐   │ Thomas Miller                            │
│ │ 🔍  Search by Account # / Name         │   │ Account #: ****1234                      │
│ └─────────────────────────────────────────┘   │ Status: Active                           │
│                                               │                                          │
│ CASH                                         │ Ledger Balance:        $4,250.00         │
│ Amount                                       │ Available Balance:     $4,100.00         │
│ ┌───────────────┐                            │                                          │
│ │    500.00     │                            │ Projected Ledger:      $4,750.00         │
│ └───────────────┘                            │ Projected Available:   $4,600.00         │
│                                               │                                          │
│ CHECKS                                        │ ⚠ Alerts                                 │
│                                               │ • Large Cash Monitoring                  │
│  [ + Add Check ]                              │                                          │
│                                               │                                          │
└───────────────────────────────────────────────┴──────────────────────────────────────────┘
```

---

# When “+ Add Check” Is Clicked

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ CHECK #1                                                                                │
│ Routing #:     [021000021]      Account #:  [*****6789]      Check #: [1054]           │
│ Amount:        [ 250.00 ]                                                               │
│                                                                                          │
│ ▸ Apply Hold                                                                            │
│                                                                                          │
│ [ Remove ]                                                                              │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

# When “Apply Hold” Is Expanded (Progressive Disclosure)

```
▼ Apply Hold
   Hold Reason:   [ New Account ▼ ]
   Hold Until:    [ 03/25/2026 ]
```

Account panel updates dynamically:

```
Immediate Availability:    $500.00
Held Amount:               $250.00
```

---

# Real-Time Totals Panel (Persistent Section)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ TRANSACTION SUMMARY                                                                     │
│                                                                                          │
│ Cash:                  $500.00                                                          │
│ Checks:                $250.00                                                          │
│ ---------------------------------------------------------------------------------------- │
│ TOTAL DEPOSIT:         $750.00                                                          │
│                                                                                          │
│ ✔ Balanced                                                                             │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

# Example: Out-of-Balance State (Visual Emphasis)

If mismatch occurs:

```
⚠ OUT OF BALANCE — $125.00
Posting disabled until resolved.
```

The “Post Deposit” button becomes visually disabled.

---

# Supervisor Override Modal (Non-Destructive)

If transaction exceeds threshold:

```
┌──────────────────────────────────────────────────────────────┐
│ SUPERVISOR APPROVAL REQUIRED                                │
│ Reason: Cash amount exceeds $10,000                         │
│                                                              │
│ Supervisor ID:   [___________]                              │
│ Password:        [___________]                              │
│ Approval Reason: [ Dropdown ▼ ]                             │
│                                                              │
│ [ Deny ]                          [ Approve & Continue ]    │
└──────────────────────────────────────────────────────────────┘
```

Upon approval:

* Modal closes  
* Deposit screen remains intact  
* Header shows:

```
Supervisor Approved ✓  (S002 – 10:47 AM)
```

---

# Persistent Cash Drawer Footer

This appears on all teller transaction screens.

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ DRAWER STATUS                                                                           │
│ Current Drawer Balance:     $12,430.00                                                  │
│ Net Cash Movement (This Tx): +$500.00                                                   │
│ Projected Drawer Balance:   $12,930.00                                                  │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

This reinforces physical accountability before posting.

---

# Visual Hierarchy Summary

| Area | Purpose |
| :---- | :---- |
| Top Bar | Session context |
| Left Column | Editable transaction inputs |
| Right Column | Read-only reference data |
| Middle Section | Dynamic line items |
| Bottom Summary | Real-time math |
| Footer | Drawer accountability |

---

# Key UX Characteristics Embedded

* No fixed check rows  
* No page reload  
* All totals live  
* Balance preview visible  
* Cash impact visible  
* Override non-destructive  
* Alerts contextual  
* Visual separation of reference vs entry

---

# If You’d Like Next

I can:

* Mock up a Withdrawal screen with mixed disbursement  
* Mock up a Non-Customer Check Cashing screen  
* Show a Transfer workflow  
* Or turn this into a developer-ready UI contract with component definitions

This is now at the level where design decisions directly reinforce internal controls.  
