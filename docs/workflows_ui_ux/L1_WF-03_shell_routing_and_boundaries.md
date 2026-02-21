## L1-WF-03 — Shell Routing & Boundaries

**Status:** **Not aligned with current codebase** — `/ops/*` shell and routing boundary model are not implemented yet.
**Current Implementation Mapping:** Only `/teller/*` shell is implemented in routes/controllers today.
**Goal:** Enforce two shells (`/teller` vs `/ops`) with clear boundaries, deterministic routing, and safe cross-links (Workstation → CIF opens in new tab).

---

# 1) Two-shell contract (non-negotiable)

## 1.1 Workstation shell (`/teller/*`)

Audience: tellers performing live transactions and drawer/session operations.

**Ergonomics:**

* Command bar present (clickable + F-keys), **not tabbable**
* Tab sequence constrained to active transaction form (or minimal non-transaction screens)
* Posting/receipt manual reset model
* Approval modal + 5-minute supervisor window model
* Reference panels read-only; view links may exist but do not join tab order

**Primary navigation model:**

* “Modes” (Deposit/Withdrawal/etc.) via command bar
* Minimal supporting screens: dashboard, session open/close, activity, reversal

## 1.2 Ops shell (`/ops/*`)

Audience: supervisors/operations staff reviewing activity and exceptions.

**Ergonomics:**

* Standard web navigation (tabbable sidebar/top nav)
* Search/filter/reporting flows
* Read-only transaction/session detail pages
* No workstation command bar

---

# 2) Namespace + layout mapping

## 2.1 Routing rule

* Any path under `/teller/*` uses `layouts/workstation`
* Any path under `/ops/*` uses `layouts/backoffice` (or application)

## 2.2 Controller base classes (recommended)

* `Teller::BaseController` → `layout "workstation"`
* `Ops::BaseController` → `layout "backoffice"`

This prevents accidental “mixed shell” screens.

---

# 3) Required module ownership (what lives where)

## 3.1 Must live in `/teller`

* Workstation context gate (WS-005)
* Lock/unlock (WS-015)
* Session open/close (WS-110/120)
* All teller transactions (WS-200–260)
* Vault transfer (WS-300)
* Recent activity + receipt viewer (WS-030/031)
* Reversal request + reversal receipt (WS-040/041)

## 3.2 Must live in `/ops`

* Branch teller activity report (OPS-010)
* Session search (OPS-020)
* Session detail read-only (OPS-030)
* Approval/exception reporting (if/when added)

---

# 4) Deterministic entry and redirect rules

## 4.1 `/teller` root

`GET /teller` resolves as:

1. If missing branch/workstation context → WS-005
2. Else if workstation locked → WS-015
3. Else if teller_session open → WS-010
4. Else → WS-100 (Session Status)

## 4.2 Cross-shell direct access

* If user hits `/ops/*` while they have a teller session open: **allow** (ops is separate shell)
* If user hits `/teller/*` while workstation locked: redirect to WS-015

---

# 5) Cross-links (Workstation ↔ Ops ↔ CIF)

## 5.1 Workstation → CIF (new tab) — locked rule

Any “View Party / View Account” link in Workstation:

* must be `target="_blank" rel="noopener noreferrer"`
* must not be tabbable in the transaction form sequence
* must not trigger dirty-state prompts (because it’s a new tab)

CIF is future, but the rule is locked now.

## 5.2 Workstation → Ops

Generally avoid in Phase 1. If you allow it:

* must be explicit “Open in Ops (new tab)” to avoid interrupting a transaction
* recommend `target="_blank"` for any Ops jump from Workstation

## 5.3 Ops → Workstation (same tab allowed)

From an Ops session detail or activity report:

* optionally provide “Open in Workstation” actions
* behavior:

  * if it navigates into an active transaction mode, it must honor WS-005 gate + WS-015 lock
  * if it preselects an account for a new transaction: focus lands on next field (Amount), not Account search

---

# 6) Navigation surfaces per shell

## 6.1 Workstation chrome

Required:

* Top context bar (display-only)
* Command bar (modes)
* Minimal global actions:

  * Lock
  * Dashboard
  * Logout (optional)

Explicitly excluded:

* Deep sidebar menus
* Long lists of admin links
* Any tabbable global navigation elements

## 6.2 Ops chrome

Required:

* Normal navigation: dashboard/reports/sessions
* Filters/search controls
* Export actions (future)

Excluded:

* Workstation command bar
* Transaction-only tab scope limitations

---

# 7) Authorization boundary (Pundit)

* `/teller/*` requires teller permissions (transaction entry, session control)
* `/ops/*` requires ops permissions (reporting, session review)
* A user can have both roles, but shells remain separate

---

# 8) Acceptance checklist

* [ ] `/teller/*` always uses workstation layout
* [ ] `/ops/*` always uses backoffice layout
* [ ] `/teller` root redirect order matches §4.1
* [ ] Workstation lock blocks all teller routes except unlock flow
* [ ] Workstation → CIF links open in new tab with noopener
* [ ] Ops pages do not inherit workstation tab-scope constraints
* [ ] No transaction entry screen appears under `/ops`

---

## Layer 1 complete

We have now locked the **Context & Shell layer**:

* WS-005 Context Gate
* WS-015 Lock/Unlock
* `/teller` vs `/ops` boundaries + cross-link policy

---

## Next workflow (Layer 2)

**L2-WF-01 — Posting & State Machine (global transaction container lifecycle)**
This is the core substrate that every transaction screen (and session close, vault transfer, reversals) relies on.
