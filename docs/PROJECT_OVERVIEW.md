# BankCORE — Project Overview

> A comprehensive overview for developers, stakeholders, and new contributors.

---

## 1. What is BankCORE?

BankCORE is a **Rails 8.1 core-banking foundation** focused on teller operations, posting integrity, cash controls, and auditable transaction workflows. It is not a full core ledger, deposit platform, or general ledger—it is a **real-time balanced event engine with cash accountability** that plugs into future core ledger, deposit, and GL systems.

### Mission

Build a controlled, balanced teller transaction and cash management platform that:

- Records and processes teller-originated financial events
- Maintains drawer and vault accountability
- Generates balanced account postings
- Supports supervisory approval workflows
- Provides auditable transaction records
- Interfaces with—but does not fully implement—CIF, account servicing, or GL systems

### Current Scope (Phase 1)

**Implemented:**

- Teller context + teller session lifecycle (open / assign drawer / close)
- Transaction flows: deposit, withdrawal, transfer, check cashing, draft issuance, vault transfer, misc receipt
- Posting engine with balancing + idempotency by request id
- Supervisor approval interrupt and approval token validation for threshold-triggered transactions
- Receipt/audit views and audit event capture

**Planned direction** is documented in `docs/*_concept.md`. **Implemented behavior** lives in `app/`, `config/`, and `db/`.

---

## 2. Design Principles

### 2.1 Foundational Principle

> **Teller is an operational event engine.** CIF, Accounts, and GL are controlled reference domains it touches—but does not own.

### 2.2 Separation of Concerns

| Domain | Responsibility |
|--------|----------------|
| **Teller** | Operational transaction events |
| **Posting Engine** | Financial debits/credits, leg generation |
| **Account Domain** | Balance maintenance |
| **Cash Control** | Physical currency accountability (drawer, vault) |
| **GL Layer** | Financial reporting derivation (stub in v1) |

### 2.3 Critical Architectural Rule

**Teller transactions must never directly modify balances.**

Flow:

```
[Teller Transaction] → [Posting Engine] → [Account Postings / Cash Movements / GL Entries / Instrument Records / Approval Records]
```

Teller transactions:

1. Generate posting legs
2. Submit them to the Posting Engine
3. The Account domain updates balances
4. The GL layer derives entries (when implemented)

This ensures future real-time posting, batch replay ability, audit integrity, and rebuildable balances.

### 2.4 Double-Entry Integrity

- All postings must be **balanced** (∑ debits = ∑ credits)
- Validated prior to commit
- Immutable after finalization
- Fully traceable

### 2.5 Auditability

- User ID and session for all activity
- Timestamps for all actions
- Supervisor approval events recorded
- Effective-dated records where applicable
- No destructive edits to financial records

### 2.6 Idempotency

- Duplicate `request_id`s handled safely
- Prevents double-posting from retries or UI double-clicks

### 2.7 Supervisory Controls

- Threshold-based supervisor approval
- Alert-triggered escalation
- Override logging with reason codes
- Approval capture: approver identity, policy trigger, correlation id

---

## 3. Domain Boundaries (What Teller Must NOT Own)

To prevent future rewrite, Teller must **not** own:

- Account product definitions
- Interest accrual logic
- GL chart structure
- Fee schedules (should reference external table)
- Account restrictions logic (should consult Account Domain)

---

## 4. Core Data Domains

1. **Identity (Parties)** — Minimal CIF layer
2. **Accounts** — Minimal ledger stub
3. **Account Parties** — Relationships
4. **Account Postings** — Ledger entries
5. **Teller Transactions** — Operational events
6. **Posting Legs** — Debit/credit legs per transaction
7. **Cash Locations** — Drawer, vault
8. **Instrument Records** — Official checks, negotiable instruments
9. **Alerts** — Warnings, blockers
10. **Approval Events** — Supervisor approvals
11. **GL Templates** — Stub for future GL mapping

---

## 5. Transaction Types

**Core:** Deposit (cash + checks), Withdrawal, Transfer  
**Expanded:** Draft issuance, Check cashing, Vault transfer, Misc receipt  
**Session:** Session close variance, handoff variance

---

## 6. Namespaces and Routes

| Namespace | Path | Purpose |
|-----------|------|---------|
| `Teller::` | `/teller/*` | Teller workstation |
| `CSR::` | `/csr/*` | Customer service |
| `Ops::` | `/ops/*` | Ops/backoffice |
| `Admin::` | `/admin/*` | Admin |

---

## 7. Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Ruby on Rails 8.1 |
| Database | MySQL (mysql2) |
| Frontend | Hotwire (Turbo + Stimulus), importmap |
| CSS | Tailwind CSS, DaisyUI |
| Background Jobs | Solid Queue |
| Cache | Solid Cache |
| WebSocket | Solid Cable |
| Server | Puma |
| Auth/Policies | Pundit, bcrypt |
| Pagination | Pagy |
| Deployment | Docker, Kamal |

---

## 8. What Developers Need to Know

### 8.1 Quick Start

```bash
bin/setup          # deps, db prepare
bin/dev            # start server
```

Health check: `GET /up`

### 8.2 Source of Truth

- **Implemented behavior:** `app/`, `config/`, `db/`
- **Phase 1 scope & acceptance criteria:** `docs/10_phase1_spec.md`
- **Architecture direction:** `docs/*_concept.md` (target, not yet implemented)
- **Transaction field requirements:** `docs/workflows_ui_ux/02_teller_transaction_requirements.md`

### 8.3 Key Implementation Paths

| Purpose | Path |
|---------|------|
| Phase 1 spec | `docs/current/10_phase1_spec.md` |
| Phase 1 status | `docs/current/10_phase1_status.md` |
| Posting engine | `app/services/posting/engine.rb` |
| Teller routes | `config/routes.rb` (namespace :teller) |
| Workflow registry | `app/services/teller/workflow_registry.rb` |
| UI theme | `docs/current/workflows_ui_ux/ui_css_docs/01_daisy_ui_theme.md` |
| UI contract | `docs/current/workflows_ui_ux/ui_css_docs/02_ui_contract.md` |

### 8.4 Required Checks Before PR

```bash
bin/ci
```

Or individually: RuboCop, Brakeman, bundler-audit, importmap audit, Rails tests.

### 8.5 Contribution Workflow

- Branch from `main`: `feat/<short-name>`
- Keep PRs small and focused
- Use imperative commit messages
- Update docs when behavior changes materially
- Use env vars or Rails credentials for secrets

See `CONTRIBUTING.md` for details.

### 8.6 UI/UX Conventions

- **Theme:** DaisyUI `bankcore-light` / `bankcore-dark` — conservative, high-contrast, institutional feel
- **Primitives:** `ui-panel`, `ui-panel-pad`, `ui-section-title`, `ui-muted`, `ui-money`, `ui-kv-row`
- **Reference panels:** Use neutral styling (`btn-ghost`, `btn-outline`); reserve `btn-primary` for the single commit action (Post/Submit/Confirm)
- **Monetary values:** `tabular-nums`, right-aligned

---

## 9. What Stakeholders Need to Know

### 9.1 Control Objectives

- Cash accountability by drawer and vault
- Transaction-level audit traceability
- Balanced financial posting enforcement
- Supervisor override governance
- Foundational ledger integrity

### 9.2 Out of Scope (Iteration 1)

- Interest accrual engines
- ACH processing
- Wire transfer processing
- Loan amortization
- Fee scheduling engines (beyond basic posting)
- Enterprise reporting platform
- Regulatory reporting automation (CTR, SAR, etc.)
- Full general ledger with financial statements

### 9.3 Future Expansion Path

- Full CIF lifecycle management
- Full product engine
- Interest and accrual systems
- Fee engine
- Regulatory reporting automation
- Enterprise GL
- Multi-channel integration (ATM, online, mobile)

### 9.4 Governance

BankCORE establishes the operational and financial integrity foundation upon which future core banking modules will be built. No architectural decisions shall preclude future migration into a full core banking platform.

---

## 10. Documentation Map

| Document | Purpose |
|----------|---------|
| [docs/README.md](README.md) | Doc index and category guide |
| `docs/current/10_phase1_spec.md` | **Authoritative** Phase 1 spec |
| `docs/current/10_phase1_status.md` | Phase 1 implementation status |
| `docs/current/architecture/` | System charter, domain boundaries |
| `docs/current/policies/` | Reversals, approvals |
| `docs/current/workflows_ui_ux/` | Teller/ops UI contracts, workflow specs |
| `docs/planned/30_posting_refactor_spec.md` | Posting decomposition spec |
| `docs/current/workflows_ui_ux/ui_css_docs/` | DaisyUI theme, UI contract |
| `CONTRIBUTING.md` | Contribution workflow |

---

## 11. First-Time Onboarding

1. Run `bin/setup`
2. Run `bin/ci` before opening a PR
3. Read `docs/current/10_phase1_spec.md` for scope
4. Read `CONTRIBUTING.md` for workflow
