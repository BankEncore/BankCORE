## L5-WF-08 — Vault Transfer (WS-300)

**Status:** **Not aligned with current codebase**
**Current Implementation Mapping:** Vault Transfer workflow/routes/controllers are not implemented in teller routes today.

---

# 1) Purpose

Move physical cash between:

* **Teller Drawer ↔ Vault**

This is a cash-control workflow, not a customer transaction.

Produces:

* Posted teller transaction
* Balanced posting batch
* Receipt block
* Session-level drawer impact

---

# 2) Routes

* `GET  /teller/vault_transfer`
* `POST /teller/vault_transfer`
* `GET  /teller/transactions/:id/receipt` (optional but recommended)

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* **Open teller session** exists
* Teller authorized for vault transfer

If fail:

* 422 blocking banner + inline errors
  (or redirect to WS-100 if no session)

---

# 4) Screen structure (Traditional / Workstation shell)

Zones:

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `VAULT TRANSFER`
4. Banner region
5. Main:

   * Entry form (tabbable)
   * Drawer/Vault balances (read-only reference panel)
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal (if required)
9. Receipt block

---

# 5) Entry form fields (tab order)

1. Direction *(required)*

   * Drawer → Vault
   * Vault → Drawer
2. Amount *(required, > 0)*
3. Reason code *(required)*

   * Excess cash
   * Replenish drawer
   * End-of-day adjustment
   * Other (requires memo)
4. Memo *(required if “Other”; recommended always allowed)*
5. Cancel
6. Post (Ctrl+Enter)

---

# 6) Totals and cash impact

## 6.1 Totals panel must show

* Direction
* Amount
* Status: BALANCED

## 6.2 Drawer footer

If Drawer → Vault:

* `Drawer Before`
* `- Cash Out`
* `Drawer After`

If Vault → Drawer:

* `Drawer Before`
* `+ Cash In`
* `Drawer After`

---

# 7) Approval triggers (strict controls)

Vault transfers are internal control events.

| Trigger                              | Approval type               |
| ------------------------------------ | --------------------------- |
| Amount ≥ threshold                   | `vault_transfer_over_limit` |
| After-hours                          | `vault_after_hours`         |
| Certain reason codes (e.g., “Other”) | `vault_reason_override`     |

**Recommended Phase 1 policy:**
Require approval for **all** vault transfers above a modest threshold.

Approval behavior:

* Neutral `[APPROVAL REQUIRED]`
* Supervisor window reuse allowed
* Approval binds to idempotency key

---

# 8) Posting legs (double-entry)

Canonical map:

## 8.1 Drawer → Vault

* **Credit**: Cashbox (Drawer Cash Out) — `amount`
* **Debit**: Vault Cash Asset — `amount`

## 8.2 Vault → Drawer

* **Debit**: Cashbox (Drawer Cash In) — `amount`
* **Credit**: Vault Cash Asset — `amount`

Balanced by definition.

---

# 9) Validation rules (blocking)

* Direction required
* Amount > 0
* Reason code required
* If “Other” reason:

  * Memo required
* Drawer must have sufficient cash for Drawer → Vault
* Open teller session required

Server authoritative:

* policy threshold checks
* approval triggers

---

# 10) Interaction with session controls

* Vault transfer attaches to **current open teller_session**
* Drawer totals used for session close must include all vault transfers
* After session close:

  * vault transfers must be blocked until a new session is opened

---

# 11) Idempotency

Vault transfer POST includes `idempotency_key`.

Server ensures:

* duplicate submit returns same receipt; never double-moves cash.

---

# 12) Receipt requirements (Vault Transfer)

Receipt must include:

* Ref #
* Timestamp
* Direction
* Amount
* Reason code
* Memo (if present)
* Drawer before/after
* Approval stamp if used

Actions:

* Print Receipt
* New Vault Transfer

Focus:

* New Vault Transfer

---

# 13) Ops visibility

Vault transfers must appear in:

* OPS teller activity totals (cash in/out)
* OPS session detail
* Approval linkage visible
* Branch-level vault reconciliation (Phase 2+)

---

# 14) Acceptance checklist (WS-300)

* [ ] Requires open teller session
* [ ] Direction + amount + reason captured
* [ ] Drawer must have sufficient funds for Drawer → Vault
* [ ] Approval triggers enforced consistently
* [ ] Balanced posting: drawer vs vault asset
* [ ] Receipt includes direction + approval stamp
* [ ] Idempotency prevents duplicate transfers
* [ ] Included in session totals for close balancing
