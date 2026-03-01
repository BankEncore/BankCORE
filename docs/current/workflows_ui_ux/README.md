---
status: current
category: current
updated: 2026-03-01
---

# Workflows UI/UX Documentation

Teller and ops UI/UX contracts, workflow specs, and implementation mapping for BankCORE.

## Purpose

This folder holds the **versioned UX contracts** and **workflow specifications** for the teller workstation shell (`/teller/*`) and the ops/backoffice shell (`/ops/*`). Use these docs for product alignment, implementation traceability, and onboarding.

## Layering

| Layer | Scope |
|-------|--------|
| **L0** | Context overview (workstation, session, roadmap) |
| **L1** | Shell and context (WS-005 context gate, WS-015 lock/unlock, teller vs ops boundaries) |
| **L2** | Posting and state machine (lifecycle, request/response schema, receipt contract) |
| **L3** | Approval (modal, window lifecycle) |
| **L4** | Session (open/close, balancing, drawer) |
| **L5** | Transaction workflows (deposit, withdrawal, transfer, check cashing, draft, bill payment, misc receipt, vault transfer, reversal) |
| **L6** | Dashboard, session status, recent activity, receipt viewer |
| **L7** | Ops (activity report, session search, session detail) |
| **X1–X3** | Navigation map, permission matrix, field-level permissions |

## Core artifacts (00_*)

- **[00_teller_ui_contract_v1.md](00_teller_ui_contract_v1.md)** — UX contract: zones, keyboard, tab scope, focus recovery, posting/receipt, errors. Implementation mapping table links contract items to current endpoints.
- **[00_stimulus_event_matrix_handoff.md](../../considering/00_stimulus_event_matrix_handoff.md)** — Stimulus event contract (considering): who emits/consumes, payloads, guards, state transitions, migration phases (PR1–PR6).
- **[00_page_endpoint_list.md](00_page_endpoint_list.md)** — Route crosswalk: workflow IDs (WS-*) to current routes; Implemented / Partial / Planned.
- **[02_teller_transaction_requirements.md](02_teller_transaction_requirements.md)** — **Source of truth** for required/optional fields per teller transaction type. Update this doc first when adding or changing transaction types or required fields; then align WorkflowRegistry, WorkflowValidator, form, and UI blocking.

## Suggested reading order

1. **Contract** → [00_teller_ui_contract_v1.md](00_teller_ui_contract_v1.md)
2. **Events** → [00_stimulus_event_matrix_handoff.md](../../considering/00_stimulus_event_matrix_handoff.md)
3. **Routes** → [00_page_endpoint_list.md](00_page_endpoint_list.md)
4. **Shell/context** → L1 workflow docs (e.g. L1_WF-01, L1_WF-02, L1_WF-03)
5. **Posting lifecycle** → L2 (e.g. L2_WF-01, L2_WF-02)
6. **Transaction types** → L5 workflow docs as needed (L5_WF-01 Deposit, etc.)

## Implementation status

- **Route and workflow mapping:** [00_page_endpoint_list.md](00_page_endpoint_list.md)
- **Gap analysis and recommendations:** [01_gap_analysis_2026-02-22.md](01_gap_analysis_2026-02-22.md)
- **Before release (recommended):** Confirm [02_teller_transaction_requirements.md](02_teller_transaction_requirements.md) matches WorkflowValidator and posting form `blockedReason` / `hasInvalid*` behavior; no required field missing from form or submit.

Each L5/L6 workflow doc includes an **Implementation** badge (Implemented | Partial | Planned) and a pointer to the endpoint list for full route details. Each L5 transaction workflow references 02_teller_transaction_requirements.md for the authoritative required/optional field list.
