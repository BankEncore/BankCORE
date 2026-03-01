---
status: planned
category: planned
updated: 2026-03-01
---

Some of the previously uploaded files (including `schema.rb`) have expired in this session. I can proceed based on what we’ve already locked architecturally, but if you want strict schema-aligned validation as we review each workflow, please re-upload `schema.rb`.

For now, here is the **complete Phase 1 workflow inventory** based on everything we have formally included.

---

# ✅ Phase 1 — Complete Workflow List (Workstation + Ops)

Below is the full set of **distinct operational workflows**, not just screens.

---

# I. Workstation Context & Control Workflows

### 1. Workstation Context Gate

* Validate branch/workstation
* Ensure user authorized
* Enforce context before entry

### 2. Workstation Lock / Unlock

* Temporarily lock terminal
* Re-auth to unlock
* Invalidate approval window

---

# II. Teller Session Lifecycle

### 3. Open Session

* Enter starting cash
* Possible approval
* Create session
* Generate open receipt

### 4. Close Session (Balancing)

* Display expected totals
* Enter counted total
* Calculate over/short
* Approval if outside tolerance
* Post close
* Generate close receipt

---

# III. Core Transaction Workflows

### 5. Deposit

* Account lookup
* Cash entry
* Check entry (multiple)
* Hold logic
* Approval (threshold/override)
* Post
* Receipt

### 6. Withdrawal

* Account lookup
* Amount entry
* Fee logic
* Overdraft handling
* Approval (threshold/override)
* Post
* Receipt

### 7. Transfer

* From account
* To account
* Amount
* Approval (threshold/override)
* Post
* Receipt

### 8. Check Cashing

* Check info capture
* Customer/non-customer logic
* Fee logic
* Approval (threshold/non-customer)
* Post
* Receipt

### 9. Bank Draft

* Funding account
* Draft amount
* Fee
* Serial assignment
* Approval (threshold)
* Post
* Receipt

### 10. Bill Payment

* Funding account
* Payee
* Amount
* Fee override approval
* Post
* Receipt

### 11. Miscellaneous Receipt

* Funding source
* GL classification
* Amount
* Approval (large/override)
* Post
* Receipt

### 12. Vault Transfer

* Direction (Drawer↔Vault)
* Amount
* Reason code (required)
* Approval (threshold/reason)
* Post
* Receipt

---

# IV. Correction / Adjustment Workflows

### 13. Reverse Transaction (Any Time)

* Validate eligibility
* Reason + memo
* Mandatory supervisor approval
* Post reversing entry
* Receipt

---

# V. Teller Lookup / Support

### 14. Recent Activity (My Transactions)

* List current session or today
* View receipt
* Initiate reversal

### 15. Receipt Viewer

* Display posted transaction
* Print
* Reverse (if eligible)

---

# VI. Approval Infrastructure Workflows

### 16. Approval — Initial Authentication

* Supervisor credential validation
* Create approval window

### 17. Approval — Window Reuse

* Confirm-only approval
* Log individual event

### 18. Approval Window Expiration

* Auto-expire
* Manual close
* Invalidate on lock/logout/session close

---

# VII. Ops (Backoffice) Workflows

### 19. Teller Activity Report (Branch/Date)

* Filter
* Aggregate totals
* Include vault + reversals

### 20. Teller Session Search

* Search by session/teller/date
* Drill down

### 21. Session Detail (Read-only)

* Session open/close info
* Transactions
* Over/short
* Approvals used

---

# VIII. Implicit Cross-Cutting Workflows

These are not screens but must be explicitly modeled:

### 22. Posting Lifecycle

* Editing
* Approval-required
* Posting
* Posted
* Manual reset

### 23. Error Severity Handling

* Blocking
* Approval-required
* Warning
* System error

### 24. Drawer Impact Calculation

* Real-time projection
* Post-update integrity

### 25. Audit Logging

* Every post
* Every approval
* Every reversal
* Every session event

---

# 📊 Total Phase 1 Workflow Count

**25 distinct operational workflows**

(Only 15 are user-facing screens; the rest are state/control flows that must exist.)

---

# Before we proceed

We should decide how you want to review:

A) Review in strict operational order (session → deposit → withdrawal → …)
B) Review by risk tier (highest control risk first: withdrawal, vault, reversal, session close)
C) Review by architectural layer (posting engine first, then UI, then approvals)

Given your system design priorities, I would recommend **B: risk tier first**, but I’ll follow your preference.
