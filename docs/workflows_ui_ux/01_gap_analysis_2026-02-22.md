# UI/UX Workflow Gap Analysis (2026-02-22)

## Scope Reviewed
- `docs/workflows_ui_ux/*` workflow contracts and mapping docs.
- Current implementation surfaces in `config/routes.rb`, teller layouts/partials, and Stimulus controllers.

## Executive Summary
The teller UX foundation is strong (shared shell, posting workspace, validation/posting lifecycle), but there are notable contract gaps across keyboard/navigation standards, receipt lifecycle, and planned workflows (bill payment, misc receipt, reversal, and most Ops reporting/search/detail pages).

## Gap Matrix

### 1) Route and workflow surface gaps

| Area | Contract expectation | Current implementation | Gap |
|---|---|---|---|
| Bill Payment (WS-250) | Dedicated teller flow endpoint and UX contract. | No `/teller/transactions/bill_payment` route; no bill payment controller/page. | Missing workflow surface. |
| Misc Receipt (WS-260) | Dedicated teller flow endpoint and UX contract. | No `/teller/transactions/misc_receipt` route; no misc receipt controller/page. | Missing workflow surface. |
| Reversal (WS-040/041) | Reversal initiation + reversal receipt routes. | No reversal routes/controllers. | Missing correction workflow. |
| Ops reports/search/detail (L7) | `/ops/reports/teller_activity`, `/ops/sessions`, `/ops/sessions/:id`. | Only `ops root` route exists today. | Ops shell largely scaffolded only. |

### 2) Teller shell interaction contract gaps

| Area | Contract expectation | Current implementation | Gap |
|---|---|---|---|
| Command bar keyboard model | F-key navigation hints and actions (F2–F4, F6–F10). | Command bar has clickable links only; no F-key handling in keyboard controller. | Keyboard parity gap for workstation users. |
| Tab scope hardening | Command bar and top context should be non-tabbable (`tabindex=-1`). | Command bar uses standard links/buttons in normal tab order. | Accessibility/interaction contract mismatch. |
| Dirty-switch confirmation | Switching transaction modes when dirty should prompt confirm. | No confirm-on-mode-switch pattern observed in command bar routing. | Data-loss prevention gap. |

### 3) Posting/receipt lifecycle UX gaps

| Area | Contract expectation | Current implementation | Gap |
|---|---|---|---|
| Receipt actions | Receipt block should include print + new transaction actions. | Receipt panel has "View Receipt / Audit" and "New Transaction", but no print action. | Print workflow missing in in-page receipt block. |
| Inline receipt replacement behavior | Contract describes receipt replacing entry form post-success. | Entry form remains; separate receipt confirmation panel toggled into view. | Behavior differs from target contract (may be acceptable if contract updated). |
| Error contract detail | Field-level ARIA invalid/description semantics in blocking states. | Global message + badges/alerts exist; no comprehensive field-level ARIA error mapping found. | Accessibility/error granularity gap. |

### 4) Documentation consistency gaps

| Area | Contract expectation | Current implementation | Gap |
|---|---|---|---|
| Endpoint mapping freshness | Mapping docs should match implemented routes. | `00_page_endpoint_list.md` marks bank draft and vault transfer as planned, but routes/pages exist for `draft` and `vault_transfer`. | Stale mapping entries risk planning confusion. |
| Ops boundary status notes | Some docs state `/ops/*` not implemented. | `namespace :ops` with `ops root` exists. | Status language outdated (partially implemented vs not implemented). |

## Strengths / Already aligned
- Shared teller shell structure and posting workspace composition are in place.
- Core transaction surfaces implemented for deposit/withdrawal/transfer/check cashing/draft/vault transfer.
- Validation, approval, posting, and receipt endpoints exist and are wired via Stimulus events.
- Read-only receipt/audit page exists with posting-leg and metadata details.

## Prioritized Recommendations

### P0 (high impact, low-to-medium lift)
1. Refresh workflow mapping docs to reflect actual implemented routes and statuses.
2. Add explicit "planned vs implemented" badges per workflow document front-matter.
3. Add print action to in-page receipt confirmation block (or document why full receipt page print is preferred).

### P1 (operator efficiency)
1. Add F-key command shortcuts in `tx_keyboard_controller` (without overriding browser-reserved keys).
2. Remove command/top-bar elements from tab sequence where contract requires (`tabindex=-1`) while preserving mouse/touch use.
3. Add dirty-state confirmation when navigating away from active transaction form.

### P2 (scope completion)
1. Implement bill payment and misc receipt transaction pages with shared posting contract.
2. Implement reversal request + reversal receipt workflow.
3. Build Ops L7 surfaces (activity report, session search, session detail) as read-only reporting tools.

## Suggested Acceptance Re-check List
- Endpoint mapping document updated and internally consistent.
- Keyboard contract test cases added (F-keys, Esc, Ctrl+Enter).
- Tab order audit completed for teller shell chrome vs active form scope.
- Receipt block includes required actions and focus recovery behavior.
- Planned workflows tracked with explicit milestone/phase tags.
