
Understand how the Reference Summary block on the transaction pages is dynamically updated

Here’s how the Reference Summary block is dynamically updated.
1. Two parts of the block
The Reference Summary has:
Session Context (Teller, Branch, Workstation, Session Status, Drawer, Cash Reference) — server-rendered once in _reference_panel.html.erb (ERB). It does not change on the client.
Transaction Snapshot, Amounts, Cash Impact, Posting Readiness, Alerts, Restrictions — updated in the browser by the reference_panel_controller (and partly by shared data-posting-form-target elements).
2. Event flow: what triggers an update
Updates are driven by a Stimulus custom event:
Something changes in the form
User edits amount, account reference, transaction type, check rows, etc.
Handlers are wired in _posting_workspace.html.erb:
tx:changed->posting-form#recalculate (e.g. from line items)
change->posting-form#recalculate (e.g. transaction type select)
input->posting-form#recalculate (e.g. amount field)
posting_form_controller#recalculate() runs
It recomputes totals, balance, readiness, cash impact, etc., and at the end dispatches:
   this.element.dispatchEvent(new CustomEvent("tx:recalc", {     bubbles: true,     detail: {       transactionType,       entries,       primaryReference: this.primaryAccountReferenceTarget.value.trim(),       counterpartyReference: ...,       cashReference: ...,       requestId: ...,       cashAmountCents: ...,       ...       totalAmountCents, debitTotal, creditTotal, imbalanceCents,       cashImpactCents, projectedDrawerCents,       readyToPost: !disabled,       blockedReason     }   }))
See posting_form_controller.js around lines 271–302.
Reference panel listens for tx:recalc
In the same wrapper div you have:
   tx:recalc->reference-panel#refresh
So every time tx:recalc is fired, reference_panel_controller#refresh(event) runs with that detail.
3. What reference_panel_controller#refresh does
In reference_panel_controller.js, refresh(event):
Reads event.detail
Uses transactionType, primaryReference, counterpartyReference, cashReference, requestId, cashAmountCents, cashImpactCents, projectedDrawerCents, readyToPost, blockedReason, etc.
Updates the panel DOM
It finds elements by data-posting-form-target="..." (inside the same workspace element) and sets their text/visibility:
Transaction Snapshot: type, primary/counterparty reference, request ID (and shows/hides counterparty row for transfers).
Amounts: not updated in this controller (they’re already set by posting_form_controller on shared targets).
Cash Impact: summaryCashIn, summaryCashOut, cashImpact, projectedDrawer via renderCashFlowSummary(...).
Posting Readiness: badge and reason via renderReadiness(readyToPost, blockedReason).
Fetches account reference snapshots
For primary, cash, and (for transfers) counterparty references it calls:
GET teller_account_reference_path?reference=<reference>
with Accept: application/json.
The backend is Teller::AccountReferencesController#show, which uses Teller::AccountReferenceSnapshot to return JSON (balance, status, alerts, restrictions).
Writes Alerts and Restrictions
After the fetch, it merges alerts/restrictions from each snapshot and renders them into:
data-posting-form-target="referenceAlerts"
data-posting-form-target="referenceRestrictions"
via renderReferenceInsights(transactionType).
So the “dynamic” part of the Reference Summary is: transaction snapshot, cash impact, readiness badge/reason, and alerts/restrictions, all driven by tx:recalc and the subsequent refresh() + API calls.
4. Where the URLs and wiring live
Reference panel is rendered inside the posting workspace:
app/views/teller/dashboard/_posting_workspace.html.erb (e.g. around line 275):
<%= render "teller/shared/reference_panel", teller_session: teller_session %>
The same div has:
data-controller="... reference-panel ..."
data-action="... tx:recalc->reference-panel#refresh ..."
data-reference-panel-account-reference-url-value="<%= teller_account_reference_path %>"
So the reference-panel controller’s scope is the whole posting workspace; it finds the summary elements (and the two alert/restriction containers) via querySelector('[data-posting-form-target="..."]') within that element.
5. End-to-end summary
Step	What happens
1	User changes the form (type, amount, account refs, line items, etc.).
2	Either posting-form#recalculate is called directly (input/change) or tx:changed is dispatched (e.g. from line_items_controller) and then posting-form#recalculate runs.
3	posting_form_controller recomputes state and dispatches tx:recalc with full detail.
4	reference-panel#refresh runs: updates transaction snapshot, cash impact, readiness; then fetches account reference JSON for primary/cash/(counterparty if transfer); then fills Alerts and Restrictions from those snapshots.
So the Reference Summary block is updated whenever the form state triggers a recalc (and thus a tx:recalc), and the server-side “dynamic” data (alerts/restrictions, and any balance/status you might show) comes from Teller::AccountReferencesController#show and Teller::AccountReferenceSnapshot.