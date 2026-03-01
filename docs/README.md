# BankCORE Documentation

Documentation is organized by status: what exists, what we're building, and what we're considering.

## Quick links

| Category | Purpose |
|----------|---------|
| [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | Onboarding — what is BankCORE, design principles, developer/stakeholder guide |
| [current/](current/) | **What we have** — authoritative specs, architecture, policies, workflow docs |
| [planned/](planned/) | **What we're building next** — bill payment, lock/unlock, posting refactor |
| [considering/](considering/) | **Ideas under evaluation** — concepts, roadmaps, design exploration |
| [reference/](reference/) | **How it works** — technical summaries, event flows, contracts |
| [archive/](archive/) | Historical or superseded docs |

## Category summaries

### current/

Accurately describes implemented behavior. Source of truth for scope and architecture.

- **10_phase1_spec.md** — Authoritative Phase 1 scope
- **10_phase1_status.md** — Implementation checklist
- **architecture/** — System charter, teller architecture
- **policies/** — Reversals, approvals
- **workflows_ui_ux/** — Endpoint mapping, transaction requirements, L0–L7 workflow specs

### planned/

Finalized scope not yet implemented.

- **L5_WF-06_bill_payment.md** — Bill payment workflow
- **WS-015_lock_unlock.md** — Workstation lock/unlock
- **30_posting_refactor_spec.md** — Posting decomposition
- **workflows.md** — Workflow inventory

### considering/

Ideas under evaluation. No commitment. Implementation authority remains `current/10_phase1_spec.md`.

- **00_teller_module_mvp.md**, **01_phase1_master_plan_concept.md**, **02_phase1_roadmape_concept.md**
- **concepts/** — Consolidated UI/UX concept docs
- **250225_notes/** — Posting architecture, integrity, regulatory
- **00_stimulus_event_matrix_handoff.md** — Proposed controller split

### reference/

Technical summaries and contracts — how things work, not scope.

- **00_project_summary_260223.md** — tx:recalc and Reference Summary
- **notes/** — Advisory spec, CSR layout, UI record pattern

## Other

- **seed_data/** — CSV seed data
- **mockups/** — HTML mockups and notes
