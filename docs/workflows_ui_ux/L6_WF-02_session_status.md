# L6-WF-02 — Session Status (WS-100)

**Status:** **Partially aligned with current codebase**
**Current Implementation Mapping:** Teller session state is shown inside existing teller pages/partials, but a dedicated WS-100 screen/route is not implemented.
**Implementation:** Planned. See [00_page_endpoint_list.md](00_page_endpoint_list.md) for route mapping.
**Purpose:** Define the gate behavior when workstation context exists but no usable open teller session is available.

## Endpoint Mapping (Proposed → Current)

| Proposed WS Surface | Current Endpoint(s) | Status | Notes |
|---|---|---|---|
| WS-100 Session Status (`/teller/session/*`) | — | Planned | No dedicated session-status route/page yet. |
| WS-110 Open Session (`/teller/session/open`) | `GET /teller/teller_session/new`, `POST /teller/teller_session` | Partial | Open-session flow exists with different route naming. |
| WS-120 Close Session (`/teller/session/*/close`) | `PATCH /teller/teller_session/close` | Partial | Close-session behavior exists with different route shape. |
| Drawer assignment (required prerequisite) | `PATCH /teller/teller_session/assign_drawer` | Implemented | Not listed in original WS-100 set, but required by current teller flow. |

## 1) Preconditions

- Workstation context present (branch + workstation)
- User is authenticated and authorized for teller workspace

## 2) States

### 2.1 No Open Session

Display:

- Clear message: no open teller session for this workstation.

Actions:

- Open Session
- Back to teller workspace root (optional)

### 2.2 Last Session Closed (Read-Only Summary)

If recent session exists, show minimal context:

- Session identifier
- Closed timestamp
- Over/short variance (if captured)

Actions:

- Open New Session

## 3) Behavior Rules

- This screen does not create postings.
- Session actions transition into existing session open/assign drawer flow.
- If a valid open session becomes available, redirect back to teller workflow entry.

## 4) Acceptance Checklist

- [ ] Clear "no session" state message
- [ ] Primary action to open a session
- [ ] Optional recent closed-session summary
- [ ] Deterministic redirect into teller workflow when session is open
