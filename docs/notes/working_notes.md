# Tellers
* Add last_name, first_name, teller_id, and PIN hash
* Wire teller_id/pin for station unlock and supervisor authorization

# Workstation
* Branch and workstation assignment stored in cookie
* Persists across teller sessions/drawers

Top Bar:
- Logo [root]
- Main Nav
    - Teller
    - Ops
- User Name
    - Log Out
    - Change Branch/Workstation

Context:
- Branch
- Workstation
- Session
- Drawer

Transactions (Workflows):
- Deposit
- Withdrawal
- Transfer
- Check Cashing

## Current Implementation Status (2026-02-22)

Completed:
- Dedicated teller shell layout with shared top bar + command bar.
- Teller controllers now inherit from a teller base controller with teller-specific context gating.
- Context and Session workflows are separated:
    - Context page: branch/workstation only.
    - Session page: teller session open/close + drawer assignment.
- Posting prerequisites now route users to Session setup with return-to behavior.
- Dashboard messaging updated with readiness guidance.
- Ops shell scaffold added (`/ops`) for future expansion.

Navigation contract implemented in teller command bar:
- Dashboard
- Deposit
- Withdrawal
- Transfer
- Check Cashing
- Bank Draft (disabled)
- Bill Payment (disabled)
- Misc Receipt (disabled)
- Vault Transfer (disabled)
- Session

## PR Summary (ready-to-use)

Title:
- Teller setup flow split: Context first, Session/Drawer second, with unified teller shell navigation

Highlights:
- Moved teller-specific flow control into teller base controller; removed teller route gating from global application controller.
- Standardized teller return-to flow so users continue to the next logical prerequisite and then resume requested work.
- Introduced teller shell layout and command bar ordering aligned to workstation UX.
- Split setup responsibilities across Context and Session pages.
- Added minimal Ops namespace scaffold and app-nav link.

## QA Checklist

- Login and shell
    - Sign in and confirm app nav shows Home / Teller / Ops.
    - Enter teller area and confirm teller shell chrome renders.

- Teller command bar
    - Confirm order: Dashboard, Deposit, Withdrawal, Transfer, Check Cashing, Bank Draft, Bill Payment, Misc Receipt, Vault Transfer, Session.
    - Confirm planned items are visible and disabled.

- Context → Session progression
    - With no branch/workstation set, opening teller transaction URL redirects to Context.
    - Context page shows branch/workstation setup only.
    - Valid context update redirects to Session setup.

- Session/drawer progression
    - Open teller session and assign drawer on Session page.
    - After drawer assignment, confirm return-to behavior routes to requested page (or dashboard default).

- Transaction gating
    - No session: redirect to Session with "Open a teller session before continuing."
    - No drawer for cash flows: redirect to Session with "Assign a drawer before continuing."
    - Transfer remains available without drawer assignment.

- Dashboard readiness
    - Confirm readiness section reflects session/drawer state.
    - Confirm Deposit/Withdrawal/Check Cashing are disabled on dashboard when drawer is not assigned.

## Validation Results

- Focused teller flow tests: passing.
- Full teller controller suite: passing.
- `bin/ci`: passing (lint, security scans, tests, seed replant).

## Release Note / Changelog Draft

### Added
- Dedicated teller workstation layout with shared teller top context bar, command bar, and teller-scoped flash rendering.
- Ops shell scaffold at `/ops` with initial dashboard placeholder.

### Changed
- Teller workflow now follows a clearer setup progression:
    - Context page manages branch/workstation only.
    - Session page manages teller session open/close and drawer assignment.
- Teller command bar order standardized to:
    - Dashboard, Deposit, Withdrawal, Transfer, Check Cashing, Bank Draft, Bill Payment, Misc Receipt, Vault Transfer, Session.
- Posting prerequisite messaging updated to guide users to next required action:
    - "Open a teller session before continuing."
    - "Assign a drawer before continuing."
- Return-to behavior improved so users can resume requested teller destination after completing setup prerequisites.

### Internal
- Teller controllers now inherit from a shared teller base controller for teller-specific flow enforcement.
- Teller-related controller tests updated for new setup progression and alert copy.

### Verification
- Teller controller suite passing.
- Full CI passing via `bin/ci`.