
# L7-WF-03 — OPS-030 Session Detail (Read-Only)

**Status:** DROP-IN SAFE

## 1) Purpose

Deep inspection of a specific teller session.

Must provide:

* Full transaction list
* Approval events
* Vault transfers
* Session open/close details

---

## 2) Route

* `GET /ops/sessions/:id`

---

## 3) Sections

### 3.1 Session Summary

* Teller
* Branch
* Workstation
* Opened/Closed timestamps
* Opening cash
* Expected closing cash
* Counted cash
* Variance
* Supervisor approval (if over/short approved)

---

### 3.2 Transaction List

Columns:

* Time
* Type
* Ref #
* Amount
* Cash Impact
* Approved?
* Reversed?
* View Receipt

Receipt view may open in:

* Same tab (recommended for Ops)
* New tab (acceptable)

---

### 3.3 Approval Events

Separate table:

* Approval Type
* Initiated By
* Approved By
* Timestamp
* Linked Ref #

---

### 3.4 Vault Transfers

Separate summary block or filtered within transaction list.

---

## 4) Hard rules

* Read-only
* No edit or delete
* Reversal initiation not allowed from Ops in Phase 1 (must be done from Workstation)

---

## 5) Acceptance checklist

* [ ] Session summary matches stored session data
* [ ] All transactions displayed
* [ ] Approval linkage visible
* [ ] Receipts viewable
* [ ] No edit controls

---

# Ops vs Workstation Boundary Confirmation

Workstation:

* Performs transactions
* Performs reversals
* Handles session open/close

Ops:

* Reviews
* Reports
* Inspects
* Does not transact

---

# Phase 1 Workflow Surface — Complete

You now have formal contracts for:

### Workstation

* Context
* Lock
* Session open/close
* All 8 transaction types
* Reversal
* Dashboard
* Activity
* Receipt viewer

### Ops

* Teller Activity Report
* Session Search
* Session Detail
