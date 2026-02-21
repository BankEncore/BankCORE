# L6-WF-01 — Teller Dashboard (WS-010)

**Status:** **Fits but needs working changes**
**Current Implementation Mapping:** Dashboard exists at `/teller` with links to implemented transaction pages (`/teller/transactions/deposit|withdrawal|transfer|check_cashing`) and context/session management.
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
