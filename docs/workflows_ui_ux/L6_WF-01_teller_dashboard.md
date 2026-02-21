# L6-WF-01 — Teller Dashboard (WS-010)

**Status:** **DROP-IN SAFE (Phase 1 contract)**
**Purpose:** A low-friction “home” for the active teller session: launch workflows, view key status, and jump to recent activity.

## 1) Preconditions

* WS context present (WS-005)
* Not locked (WS-015)
* If no open teller_session → redirect to **WS-100 Session Status**

## 2) Dashboard sections

### 2.1 Session Status Summary (read-only)

* Session ID
* Opened at timestamp
* Opening cash
* Current projected cash (server authoritative)
* Alerts:

  * “Supervisor window active (mm:ss)” (if present; display-only)

### 2.2 Quick Actions (command equivalents; click only)

Buttons:

* Deposit
* Withdrawal
* Transfer
* Check Cashing
* Bank Draft
* Bill Payment
* Misc Receipt
* Vault Transfer

Rules:

* Buttons are not part of tab order if you are enforcing “tab affects only active transaction.”
  (If dashboard is the active screen, it’s acceptable to allow normal tabbing here. Your earlier rule was “tab sequence should only affect active form/transaction.” Dashboard can be treated as a non-transaction screen with normal tabbing.)

### 2.3 Recent Activity (current session by default)

* Table list (5–10 most recent):

  * Time
  * Type
  * Ref #
  * Amount
  * Status (Reversed/Approved/Etc.)
  * Action: View Receipt

## 3) Navigation rules

* Entering a transaction from dashboard opens the transaction screen in the same tab.
* Viewing receipt opens WS-031 (same tab).

## 4) Acceptance checklist

* [ ] Redirects to WS-100 when no session
* [ ] Shows session summary + quick actions
* [ ] Shows recent activity snapshot
* [ ] No posting occurs on dashboard

---

# L6-WF-02 — Session Status (WS-100)

**Status:** **DROP-IN SAFE (Phase 1 contract)**
**Purpose:** The “gate” screen when teller has workstation context but no open session (or session is closed).

## 1) Preconditions

* WS context present
* Not locked

## 2) States

### 2.1 No Open Session

Display:

* “No open teller session for this workstation.”
  Actions:
* Open Session (WS-110)
* Back to Workstation Landing (optional)

### 2.2 Session Closed (read-only summary of last session)

If a most-recent session exists:

* Last session ID
* Closed timestamp
* Over/short (if recorded)
  Actions:
* Open New Session

## 3) Acceptance checklist

* [ ] Clear “no session” messaging
* [ ] Single primary CTA to open session
* [ ] Optional last session summary only (no drill-down required in Phase 1)

---

# L6-WF-03 — Recent Activity (WS-030)

**Status:** **DROP-IN SAFE (Phase 1 contract)**
**Purpose:** Let teller find prior posted transactions quickly for reprint and reversal initiation.

## 1) Default scope

* Default filter: **Current open teller_session**
* Optional toggles:

  * Today
  * This session (default)
  * Search by Ref #

## 2) List columns (table)

* Time
* Type
* Ref #
* Primary account masked (if applicable)
* Amount (signed if useful)
* Flags:

  * Approved
  * Reversed (and reversal ref)

Row actions:

* View Receipt (WS-031)
* Reverse (WS-040) *(only if eligible)*

## 3) Eligibility indicators

If not eligible to reverse:

* Reverse action disabled with tooltip text (display-only)

## 4) Acceptance checklist

* [ ] Fast list, minimal filters
* [ ] View Receipt always available
* [ ] Reverse only when eligible
* [ ] Defaults to current session scope

---

# L6-WF-04 — Receipt Viewer (WS-031)

**Status:** **DROP-IN SAFE (Phase 1 contract)**
**Purpose:** Read-only view of a posted receipt, with print and (if eligible) reversal.

## 1) Content

* Render the same receipt block as post-success
* Show:

  * Print
  * Back to Activity
  * Reverse (if eligible) → WS-040

## 2) Rules

* Receipt is server-authoritative and immutable
* If already reversed:

  * show reversal linkage and disable reverse button

## 3) Acceptance checklist

* [ ] Receipt matches printed receipt layout
* [ ] Print works identically to post-success
* [ ] Reversal launch is controlled by eligibility

---

## Next after L6

Layer 7 is Ops (Backoffice) shell workflows:

* OPS-010 Teller Activity Report
* OPS-020 Session Search
* OPS-030 Session Detail (read-only)

Confirm to proceed.
