# BankCORE — Phase 1 Specification (Cohesive: Core + Expanded)

## Status
This document is the **authoritative** Phase 1 scope and acceptance criteria.

Implementation progress is tracked separately in [docs/10_phase1_status.md](docs/10_phase1_status.md) (non-authoritative snapshot).

Other documents in `docs/` may provide charter/architecture/roadmap/UX guidance, but **must not redefine Phase 1 scope**.

---

## 1) Purpose
Phase 1 delivers a production-grade Teller Operations module that:
- Processes teller-originated financial transactions
- Enforces double-entry accounting integrity (balanced posting legs)
- Maintains cash drawer and vault accountability
- Supports supervisory approval gating with audit-grade traceability
- Produces immutable, reviewable posting artifacts

Phase 1 intentionally keeps CIF/accounts/GL minimal: Teller **touches** reference domains, but does not fully own them.

---

## 2) Foundational principles (non-negotiable)
1. **Teller is an operational event engine**. It originates posting intent; it is not a general ledger.
2. All postings must be **balanced** ($\sum debits = \sum credits$) and persisted as an **immutable posting package**.
3. Cash-affecting transactions must be attributable to an **open teller session** and an **assigned cash location** (drawer/vault).
4. Approval gating is **policy-driven**, recorded, and auditable.

---

## 3) Phase 1 scope (in-scope)

### 3.1 Teller environment and session lifecycle
- Set teller context (branch + workstation)
- Open teller session
- Assign/change drawer for the session
- Enforce: cash-affecting posting is blocked if no drawer is assigned
- Close teller session with minimal balancing capture:
  - declared cash
  - expected cash
  - variance
  - variance reason/notes

### 3.2 Teller transaction types

**Core transactions**
- Deposit
  - Supports cash and 0..N check line items
  - Supports optional hold metadata capture (non-destructive)
- Withdrawal (**cash-only** in Phase 1)
- Transfer (account-to-account)

**Expanded transactions**
- Draft issuance
- Check cashing
- Vault transfer (drawer <-> vault; vault <-> vault if required)

### 3.3 Teller workstation UX requirements
- A transaction entry shell that separates:
  - Entry panel (editable inputs)
  - Reference panel (**read-only at-a-glance summary**)
  - Totals / balance state
- Real-time totals and out-of-balance indicators while entering a transaction
- Receipt/audit view for posted transactions

### 3.4 Supervisory approvals (Phase 1)
- Non-destructive prompt when approval is required
- Approval capture must record at minimum:
  - approver identity
  - approval reason/policy trigger
  - correlation/request id

---

## 4) Out of scope (explicit non-goals)
- Full CIF onboarding/maintenance workflows
- Full general ledger subsystem (financial statements, period close, detailed GL rules engine)
- Advanced fraud/risk engines
- ATM/ITM integration
- Comprehensive customer/channel servicing beyond teller workstation flows

---

## 5) Acceptance criteria (testable)

### 5.1 Posting integrity
- Every posted transaction results in a persisted posting package with:
  - balanced legs
  - consistent currency
  - request/correlation id
  - actor + teller session + branch + workstation attribution
- Duplicate request ids are handled safely (idempotency).

### 5.2 Cash control
- Cash-affecting transactions cannot be posted unless:
  - teller session is open, and
  - a drawer/cash location is assigned.
- The cash leg for deposits/withdrawals must be derived from the assigned drawer and cannot be overridden by client-submitted parameters.

### 5.3 Deposit (cash + checks)
- Supports $n \ge 0$ checks.
- Displays cash subtotal, check subtotal, and effective total.
- Blocks posting when out-of-balance.
- Captures hold metadata without breaking balancing.

### 5.4 Withdrawal (cash-only)
- Supports cash-only withdrawal.
- Displays net cash movement and projected drawer impact.
- Blocks posting when prerequisites are missing or out-of-balance.

### 5.5 Transfer
- Requires both from/to account references.
- Produces balanced legs.

### 5.6 Draft / Check cashing / Vault transfer
- Each expanded transaction type:
  - produces a balanced posting package,
  - enforces prerequisite checks,
  - supports approval gating where required,
  - persists auditable metadata (who/when/where/what).

### 5.7 Receipt / audit
- A posted transaction is viewable in a receipt/audit-friendly format:
  - context (teller/session/drawer/branch/workstation)
  - transaction type and references
  - posting legs summary
  - timestamps and correlation/request id

### 5.8 Close-out
- Closing a teller session captures declared cash and produces a variance calculation.
- Close-out creates an auditable record (who closed, when, variance, notes).

---

## 6) Milestones (sequencing only; does not change scope)
These milestones are for implementation ordering and risk control.

- **Milestone 1 (Core workstation viable)**
  - Context + open session + assign drawer
  - Deposit / Withdrawal (cash-only) / Transfer
  - Real-time totals + balance state + approval prompt baseline
  - Receipt/audit view baseline

- **Milestone 2 (Expanded transaction coverage)**
  - Draft issuance
  - Check cashing
  - Vault transfers
  - Approval gating hardening

- **Milestone 3 (Close-out and operational polish)**
  - Session close-out with declared/expected/variance capture
  - Reporting/UX polish and reliability hardening

---

## 7) Related documents (supporting)
- `docs/00_system_charter_concept.md` — charter/product intent
- `docs/03_teller_focused_architecture_concept.md` — domain boundaries and architecture direction
- `docs/02_phase1_roadmape_concept.md` — implementation sequencing roadmap
- `docs/00_teller_module_mvp.md` — conceptual UX/workflow notes (must align to this spec)
