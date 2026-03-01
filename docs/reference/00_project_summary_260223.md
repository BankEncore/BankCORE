---
status: reference
category: reference
updated: 2026-03-01
---

Understand how the Reference Summary block on the transaction pages is dynamically updated.

The Reference Summary is a **transaction snapshot**: it shows the current transaction and whether it is balanced, so the user can see what will be posted and how it will affect the ledger/cash. Session context (Teller, Branch, Workstation, Session Status, Drawer, Cash Reference) is shown in the header only, not repeated here. Alerts and Restrictions are deferred to future CIF integration. The former "Live Totals" and "Cash Impact Footer" panels have been removed; their content is consolidated into the Reference Summary.

---

## 1. What the Reference Summary contains

The Reference Summary has four sections, all updated in the browser from form state and the `tx:recalc` event:

- **Transaction Snapshot** — type, primary/counterparty reference, request ID (counterparty row shown for transfers only). Updated by reference_panel_controller from `tx:recalc` detail.
- **Amounts** — entered cash, check subtotal, effective total, debits/credits, imbalance. Updated by posting_form_controller on shared `data-posting-form-target` elements before dispatching `tx:recalc`.
- **Cash Impact** — cash in, cash out, net drawer impact, projected drawer. Updated by reference_panel_controller via `renderCashFlowSummary(...)` from `tx:recalc` detail.
- **Posting Readiness** — badge (Ready to Post / Blocked) and reason. Updated by reference_panel_controller via `renderReadiness(readyToPost, blockedReason)` from `tx:recalc` detail.

No account-reference API calls are made for this panel; all data comes from the form and the `tx:recalc` payload.

---

## 2. Event flow: what triggers an update

1. Something changes in the form (amount, account reference, transaction type, check rows, etc.).
2. Handlers in _posting_workspace.html.erb run: `tx:changed->posting-form#recalculate`, `change->posting-form#recalculate`, `input->posting-form#recalculate`.
3. **posting_form_controller#recalculate()** runs: recomputes totals, balance, readiness, cash impact; updates Amounts targets (cashSubtotal, checkSubtotal, totalAmount, debitTotal, creditTotal, imbalance, cashImpact, projectedDrawer); then dispatches:
   ```js
   this.element.dispatchEvent(new CustomEvent("tx:recalc", {
     bubbles: true,
     detail: {
       transactionType, entries, primaryReference, counterpartyReference, cashReference,
       requestId, cashAmountCents, ..., totalAmountCents, debitTotal, creditTotal, imbalanceCents,
       cashImpactCents, projectedDrawerCents, readyToPost: !disabled, blockedReason
     }
   }))
   ```
   See posting_form_controller.js around lines 287–311.
4. **reference-panel** listens: `tx:recalc->reference-panel#refresh`.
5. **reference_panel_controller#refresh(event)** runs with `event.detail`: updates Transaction Snapshot (type, refs, request ID), shows/hides counterparty row for transfer, calls `renderCashFlowSummary(...)` and `renderReadiness(...)`. It no longer fetches account reference JSON or renders Alerts/Restrictions.

---

## 3. Where the wiring lives

- Reference panel partial: [app/views/teller/shared/_reference_panel.html.erb](app/views/teller/shared/_reference_panel.html.erb) — contains only the four sections above.
- Posting workspace: [app/views/teller/dashboard/_posting_workspace.html.erb](app/views/teller/dashboard/_posting_workspace.html.erb) renders the reference panel; the same wrapper div has `data-controller="... reference-panel ..."` and `data-action="... tx:recalc->reference-panel#refresh ..."`.
- reference_panel_controller finds summary elements via `querySelector('[data-posting-form-target="..."]')` within the workspace element.

---

## 4. End-to-end summary

| Step | What happens |
|------|----------------|
| 1 | User changes the form. |
| 2 | posting-form#recalculate runs (directly or via tx:changed). |
| 3 | posting_form_controller updates Amounts targets and dispatches tx:recalc with full detail. |
| 4 | reference-panel#refresh runs: updates Transaction Snapshot, Cash Impact, and Posting Readiness from event.detail. |

The Reference Summary is updated whenever the form state triggers a recalc. All displayed data is derived from the form and the single tx:recalc payload; no separate account-reference requests are used for this panel.
