## L1-WF-02 — Workstation Lock/Unlock (WS-015)

**Status:** **DROP-IN SAFE (schema-aligned)** using `sessions` + `audit_events` + existing context models; no new tables required.
**Goal:** Allow a teller to temporarily secure the workstation **without closing the teller_session**, while guaranteeing that any privileged state (approval window) is invalidated.

---

# 1) Workflow purpose and invariants

## 1.1 Purpose

* Teller can step away briefly
* Workstation becomes unusable until unlocked
* Teller session stays **OPEN**
* Supervisor approval window is **destroyed** on lock (mandatory)

## 1.2 Invariants

* Locking **must not**:

  * close teller_session
  * change branch/workstation context
  * clear in-progress transaction data *unless you explicitly choose “Cancel & Lock”*

---

# 2) Routes and entry points

## 2.1 Routes (recommended)

* `POST /teller/lock` → lock now
* `GET  /teller/locked` → locked screen
* `POST /teller/unlock` → unlock attempt

## 2.2 Entry points

* Command bar button: `Lock`
* Keyboard: optional (recommend **NOT** binding a global key in v1 to avoid browser conflicts; keep it a button)

---

# 3) Lock behavior (POST /teller/lock)

## 3.1 What happens immediately

1. Set server-side session flag: `workstation_locked = true`
2. Record `locked_at` timestamp in session (server-side)
3. **Invalidate supervisor approval window** (required)
4. Redirect to `/teller/locked`

## 3.2 Approval window invalidation rule

On lock:

* mark current approval window as closed (if present), reason: `lock`
* after lock, no approvals can be granted without re-authentication

(Implementation is either:

* if you store window state in DB → set `closed_at/closed_reason`
* if stored in session-only → clear it)

## 3.3 Dirty transaction handling (must choose one)

**Phase 1 recommendation:** lock is allowed even if transaction form is dirty, but you must be explicit:

* Option A (recommended): `Lock` triggers confirm:

  * “Continue editing” / “Cancel transaction & lock”
* Option B: `Lock` always locks immediately and preserves form state in browser (risky if you don’t persist draft state)

Given your “no surprises” rule, **Option A** is the contract-default.

---

# 4) Locked screen (GET /teller/locked)

## 4.1 Screen requirements

* Uses Workstation layout but with **no command bar actions** enabled
* Displays:

  * Branch / Workstation
  * Teller identity
  * Teller session status (OPEN)
  * Locked timestamp

## 4.2 Tabbable controls (minimal)

1. Password field (or “Unlock” control as applicable)
2. Unlock button
3. Logout (optional)

No other navigation should be available.

---

# 5) Unlock behavior (POST /teller/unlock)

## 5.1 Authentication requirement

Unlock must require **re-authentication**. Use existing auth stack:

* simplest: require current user password
* alternative: re-check Devise session freshness (not sufficient alone for a lock screen)

## 5.2 On success

1. Clear `workstation_locked` flag
2. Redirect to:

   * last teller page (preferred), else
   * `/teller/dashboard`

## 5.3 On failure

* Show blocking inline error on password field
* Keep on locked screen
* Do not change focus unpredictably (focus password field)

---

# 6) Audit logging (Phase 1 minimum)

Using your existing `audit_events` table (present in schema):

Log these events (each as one row):

* `workstation.locked`

  * metadata: `branch_id`, `workstation_id`, `teller_session_id`, `user_id`, `locked_at`
* `workstation.unlock_succeeded`

  * metadata: same + `unlocked_at`
* `workstation.unlock_failed`

  * metadata: same + `attempt_count` (optional)

Also log approval window closure if you track it:

* `approval_window.closed` with reason `lock`

---

# 7) Hard rules / acceptance checklist

* [ ] Lock does not close teller_session (`teller_sessions.status` remains `open`)
* [ ] Locked screen blocks all `/teller/*` routes except `/teller/locked` and `/teller/unlock`
* [ ] Unlock requires re-authentication
* [ ] Lock **always** invalidates supervisor approval window
* [ ] Lock/unlock events are audit logged
* [ ] If transaction dirty, user is prompted before locking (default contract)

