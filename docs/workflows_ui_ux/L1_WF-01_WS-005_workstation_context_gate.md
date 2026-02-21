## L1-WF-01 — Workstation Context Gate (WS-005)

**Status:** **DROP-IN SAFE (schema-aligned)** — uses existing tables/columns in `schema.rb` (`branches`, `workstations`, `teller_sessions`, `users`, `sessions`).
**Goal:** No `/teller/*` workflow runs without a valid **Branch + Workstation** context, and teller actions requiring a shift require an **open teller_session**.

---

# 1) Context objects (authoritative)

From `schema.rb`:

* **Branch**: `branches(id, code, name)`
* **Workstation**: `workstations(id, branch_id, code, name)`
* **Teller Session (shift)**: `teller_sessions(id, branch_id, workstation_id, user_id, status, opened_at, closed_at, opening_cash_cents, expected_closing_cash_cents, closing_cash_cents, cash_variance_cents, cash_location_id, ...)`

  * `status` default `"open"`
* **User auth session**: `sessions(user_id, ip_address, user_agent)` (login sessions)

**Global runtime context (expected app pattern):**

* `Current.user`
* `Current.branch`
* `Current.workstation`
* `Current.teller_session` *(if open)*

---

# 2) Gate responsibilities (what it must enforce)

## 2.1 Required to enter any `/teller/*` page

* Logged-in user (`Current.user` present)
* Valid Branch selected
* Valid Workstation selected
* Workstation belongs to branch (`workstations.branch_id == branches.id`)

## 2.2 Required to post any teller transaction

In addition to the above:

* Open teller session exists for current user + workstation

  * `teller_sessions.user_id == Current.user.id`
  * `teller_sessions.workstation_id == Current.workstation.id`
  * `teller_sessions.status == "open"`
  * `closed_at IS NULL` (recommended invariant)

> Exception: `/teller/session/open` must be allowed when no open teller_session exists.

---

# 3) Canonical routing rules

## 3.1 `/teller` entry

`GET /teller` redirects deterministically:

1. If missing branch/workstation context → **WS-005 Context Gate**
2. Else if teller_session open for user+workstation → **WS-010 Dashboard**
3. Else → **WS-100 Session Status** (or directly WS-110 Open Session)

## 3.2 All `/teller/transactions/*` and `/teller/vault/*`

* If no open teller_session → redirect to **WS-100 Session Status** with blocking banner:

  * `BLOCKED: No open teller session for this workstation.`

## 3.3 `/teller/session/open`

* Allowed without open teller_session
* Still requires branch/workstation context

---

# 4) Context selection screen contract (WS-005)

## 4.1 Inputs (tabbable)

* Branch selector *(recommended: select by `branches.code`)*
* Workstation selector *(filtered to selected branch; select by `workstations.code`)*
* Continue button

## 4.2 Validation (blocking)

* Invalid branch code → blocking error (field + banner)
* Invalid workstation code → blocking error
* Workstation not in branch → blocking error
* Unauthorized workstation (policy) → blocking error *(authorization hook; not schema-specific)*

## 4.3 On success

* Persist context (implementation choice):

  * server-side session variables (recommended), or
  * a user preference record (not in schema today), or
  * workstation assignment record (future)

Then redirect according to §3.1.

---

# 5) Failure modes (must be deterministic)

| Condition                                                                  | Required behavior                                                        |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Branch deleted/disabled (future)                                           | Block and force reselection                                              |
| Workstation deleted/branch mismatch                                        | Block and force reselection                                              |
| User tries `/teller/*` without context                                     | Redirect to WS-005                                                       |
| User has context but no open teller_session and attempts transaction entry | Redirect to WS-100                                                       |
| Multiple open sessions exist for same user/workstation (should not happen) | Block with SYSTEM ERROR banner and require supervisor intervention (Ops) |

---

# 6) Data integrity constraints (recommended to enforce soon)

These are not in schema today, but should be enforced via validations and (ideally) DB constraints:

## 6.1 One open session per user per workstation

App rule:

* At most one `teller_sessions` row where:

  * `user_id`, `workstation_id`, `status == "open"`

## 6.2 Branch consistency

When creating a teller_session:

* `teller_sessions.branch_id` must equal `workstations.branch_id`

(You already have `teller_sessions.branch_id` and `teller_sessions.workstation_id` in schema, so enforce this invariant in code.)

---

# 7) UI integration (Workstation shell)

Even on WS-005:

* Use Workstation shell chrome OR a simplified “pre-shell” layout—either is acceptable **as long as**:

  * It’s clear the user cannot transact until context is set
  * No command bar shortcuts are active until context is valid

---

# 8) Acceptance checklist (WS-005)

* [ ] Any `/teller/*` request without branch/workstation redirects to WS-005
* [ ] Workstation selection is constrained to the chosen branch
* [ ] Transactions cannot be posted without an open teller_session
* [ ] `/teller` redirects deterministically based on context + session state
* [ ] Session open/close endpoints enforce branch/workstation invariants

---

## Next workflow to review (Layer 1)

**L1-WF-02 — Workstation Lock/Unlock (WS-015)**
This must explicitly define: lock trigger points, unlock authentication, and invalidation rules for the supervisor approval window.
