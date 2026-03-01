---
status: planned
category: planned
updated: 2026-03-01
---

# WS-015 — Workstation Lock/Unlock

> **Status:** Planned. Not implemented. Lock/unlock routes are not in `config/routes.rb`.

## Summary

Allow a teller to temporarily secure the workstation **without closing the teller session**, while invalidating any privileged state (approval window).

**Proposed routes:**
- `POST /teller/lock` → lock now
- `GET /teller/locked` → locked screen
- `POST /teller/unlock` → unlock (requires re-authentication)

**Full specification:** See [current/workflows_ui_ux/L1_WF-02_WS-015_workstation_lock_unlock.md](../current/workflows_ui_ux/L1_WF-02_WS-015_workstation_lock_unlock.md) for detailed behavior, invariants, audit logging, and acceptance checklist.
