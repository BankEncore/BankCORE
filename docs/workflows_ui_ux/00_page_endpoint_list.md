# Proposed Endpoint Mapping (Workflow Spec → Current BankCORE)

Use this as the authoritative crosswalk between workflow proposal IDs and the endpoints currently implemented in `config/routes.rb`.

## Legend

- **Implemented**: exists now in routes/controllers
- **Partial**: behavior exists, but not as the exact proposed endpoint/screen
- **Planned**: not implemented yet

## Workstation / Context

| Workflow | Proposed Endpoint | Current Endpoint(s) | Status | Notes |
|---|---|---|---|---|
| WS-000 Workstation Landing | `/teller/*` | `GET /teller` | Implemented | Teller root is `teller/dashboard#index`. |
| WS-005 Workstation Context Gate | dedicated WS-005 page | `GET /teller/context`, `PATCH /teller/context` | Partial | Context gating exists through context resource and posting prerequisites. |
| WS-010 Teller Dashboard | `/teller/dashboard` (implied) | `GET /teller` | Implemented | Dashboard is current teller root route. |
| WS-015 Workstation Locked / Suspend | `/teller/locked`, `/teller/lock`, `/teller/unlock` | — | Planned | Lock/unlock routes are not implemented. |

## Session Lifecycle

| Workflow | Proposed Endpoint | Current Endpoint(s) | Status | Notes |
|---|---|---|---|---|
| WS-100 Session Status | `/teller/session/*` | — (no dedicated WS-100 page) | Planned | Session state appears in teller UI, but no standalone route. |
| WS-110 Open Session | `/teller/session/open` | `GET /teller/teller_session/new`, `POST /teller/teller_session` | Partial | Open-session behavior exists under `teller_session` resource naming. |
| WS-120 Close Session (Balancing) | `/teller/session/*/close` | `PATCH /teller/teller_session/close` | Partial | Close flow exists with different route shape. |
| Drawer assignment (related) | (not listed in proposal section) | `PATCH /teller/teller_session/assign_drawer` | Implemented | Required prerequisite route in current implementation. |

## Transaction Entry Modes

| Workflow | Proposed Endpoint | Current Endpoint(s) | Status | Notes |
|---|---|---|---|---|
| WS-200 Deposit | `/teller/transactions/deposit` | `GET /teller/transactions/deposit`, `GET /teller/deposits/new`, `POST /teller/deposits` | Implemented | Dedicated page + typed create endpoint both exist. |
| WS-210 Withdrawal | `/teller/transactions/withdrawal` | `GET /teller/transactions/withdrawal`, `GET /teller/withdrawals/new`, `POST /teller/withdrawals` | Implemented | Dedicated page + typed create endpoint both exist. |
| WS-220 Transfer | `/teller/transactions/transfer` | `GET /teller/transactions/transfer`, `GET /teller/transfers/new`, `POST /teller/transfers` | Implemented | Dedicated page + typed create endpoint both exist. |
| WS-230 Check Cashing | `/teller/transactions/check_cashing` | `GET /teller/transactions/check_cashing`, `GET /teller/check_cashings/new`, `POST /teller/check_cashings` | Implemented | Dedicated page + typed create endpoint both exist. |
| WS-240 Bank Draft | `/teller/transactions/bank_draft` | — | Planned | Not in routes/controllers yet. |
| WS-250 Bill Payment | `/teller/transactions/bill_payment` | — | Planned | Not in routes/controllers yet. |
| WS-260 Misc Receipt | `/teller/transactions/misc_receipt` | — | Planned | Not in routes/controllers yet. |
| WS-300 Vault Transfer | `/teller/vault_transfer` | — | Planned | Not in routes/controllers yet. |

## Shared Posting / Approval / Receipt APIs

| Proposed Contract Area | Current Endpoint(s) | Status | Notes |
|---|---|---|---|
| Validate transaction | `POST /teller/transactions/validate` | Implemented | JSON validation endpoint used by Stimulus flow. |
| Posting check | `POST /teller/posting/check` | Implemented | Posting prerequisite check endpoint. |
| Submit posting | `POST /teller/posting` | Implemented | Core posting endpoint for transaction pages. |
| Supervisor approval | `POST /teller/approvals` | Implemented | Credential + signed token approval flow. |
| Receipt viewer | `GET /teller/receipts/:request_id` | Implemented | Read-only receipt/audit endpoint by request ID. |

## Teller Lookup / Receipts (Proposal vs Current)

| Workflow | Proposed Endpoint | Current Endpoint(s) | Status | Notes |
|---|---|---|---|---|
| WS-030 Recent Activity (My Transactions) | dedicated page | — | Planned | No dedicated recent-activity route yet. |
| WS-031 Receipt Viewer (Read-only) | dedicated WS-031 route | `GET /teller/receipts/:request_id` | Partial | Receipt reading exists, but not as WS-031 screen contract. |

## Corrections / Reversals

| Workflow | Proposed Endpoint | Current Endpoint(s) | Status | Notes |
|---|---|---|---|---|
| WS-040 Reverse Transaction (Request) | `/teller/transactions/:id/reversal` | — | Planned | Reversal routes/controllers not implemented yet. |
| WS-041 Reversal Receipt (Read-only) | dedicated reversal receipt route | — | Planned | Reversal receipt not implemented yet. |

---

## Deferred (still reasonable to postpone)

- Cash adjustments outside reversal framework
- Denomination breakdown screens (v1.1+)
- CTR/WCTR data capture screens (unless Phase 1 scope requires them)
- Standalone holds management screens beyond embedded deposit/check flows
