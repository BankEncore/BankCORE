**Implementation Status:** Fits but needs working changes.
**Current Implementation Mapping:** Workstation context is managed via `/teller/context`; session/drawer management is handled on `/teller/teller_session/new` with open/assign/close actions under `/teller/teller_session`; `/ops/*`, vault, and reversal sections in this file are roadmap-only today.

Some previously uploaded files have expired in this session (including `schema.rb`). If you want this review to be **schema-aligned and drop-in safe**, re-upload `schema.rb`. If not, we can proceed with the **architecture-first contract review** using what we’ve already locked.

## C) Review by architectural layer

We’ll review workflows in this order:

1. **Context & Shell**

   * Workstation context gate
   * Workstation lock/unlock
   * Shell routing (`/teller` vs `/ops`) + new-tab CIF links (future)

2. **Posting & State Machine**

   * Transaction container lifecycle (editing → validating → approval-required → posting → posted → manual reset)
   * Idempotency and double-post prevention
   * Receipt block behavior

3. **Approval System**

   * Approval modal + focus rules
   * Approval window lifecycle (create/reuse/expire/invalidate)
   * Approval logging requirements
   * Two-party control (teller initiates, supervisor approves, no self-approval)

4. **Session/Drawer Control**

   * Open session
   * Close session/balancing
   * How session immutability interacts with reversals and vault

5. **Transaction Workflows**

   * Deposit, Withdrawal, Transfer
   * Check cashing, Bank draft, Bill payment, Misc receipt
   * Vault transfer (WS-300)

6. **Corrections**

   * Any-time reversal (WS-040/041), cross-session rules, drawer impact rules

7. **Ops Reporting**

   * Teller activity report
   * Session search
   * Session detail read-only (including approvals/reversals/vault)

---

## Layer 1 to start: Context & Shell workflows (enumerated)

### L1-WF-01 Workstation Context Gate (WS-005)

* Enforces Branch/Workstation presence before any `/teller/*` action
* Confirms authorization for user at that workstation
* Defines “no session” vs “session open” routing behavior

### L1-WF-02 Workstation Lock/Unlock (WS-015)

* Locks terminal without closing session
* Requires re-auth to unlock
* **Invalidates approval window** on lock

### L1-WF-03 Shell Routing & Boundaries

* `/teller/*` uses Workstation shell (command bar not tabbable; transaction tab-scope rules)
* `/ops/*` uses Backoffice shell (normal navigation/tabbing)
* Workstation → CIF opens new tab (future)
