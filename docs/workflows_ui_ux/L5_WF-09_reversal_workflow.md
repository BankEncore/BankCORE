# L5-WF-09 — Reversal (WS-040 / WS-041)

**Status:** **Not aligned with current codebase**
**Current Implementation Mapping:** Reversal workflow/routes/controllers are not implemented in teller routes today.
**Implementation:** Planned. See [00_page_endpoint_list.md](00_page_endpoint_list.md) for route mapping.

This is the highest-control workflow in Teller Phase 1.

Reversal is:

* Always a **new posting event**
* Always **approval required**
* Always **linked to the original transaction**
* Never destructive (no deletes, no edits of original)

---

# 1) Purpose

Reverse a previously posted teller transaction.

Reversal:

* Creates a new `teller_transaction`
* Creates a new `posting_batch`
* Offsets the original financial impact
* Links original ↔ reversal
* Produces a reversal receipt

---

# 2) Routes

* `GET  /teller/transactions/:id/reversal` → WS-040 (Review & Confirm)
* `POST /teller/transactions/:id/reversal` → Approval → Post → WS-041 Receipt

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* User authorized to reverse
* Original transaction exists and is posted
* Original transaction not already reversed (if full reversal model)
* Reversal allowed by policy (time window optional Phase 2)

**Open teller session required?**

Yes — Phase 1 rule:

* Reversal must post into the **current open teller session**
* If no open session → redirect to WS-100

---

# 4) Reversal model

## 4.1 Reversal is not an edit

Never:

* Modify original transaction
* Modify original posting batch
* Delete anything

Instead:

* Create a new transaction with:

  * `reversal_of_transaction_id`
  * `reversal_reason_code`
  * `reversal_memo`
* Create a new posting batch with inverted legs

---

# 5) Screen structure (WS-040)

Zones:

1. Context bar
2. Header: `REVERSAL`
3. Banner region
4. Review panel (read-only):

   * Original Ref #
   * Original type
   * Original timestamp
   * Original teller/session
   * Financial breakdown
5. Reversal form (tabbable):

   * Reason code *(required)*
   * Memo *(required; mandatory narrative)*
6. Cancel
7. Reverse (Post)

No financial fields are editable.

---

# 6) Approval rules

Reversal is:

* **ALWAYS approval required**
* No exception

Approval type:

* `transaction_reversal`

Approval context must include:

* original_transaction_id
* original_ref
* original_amount
* original_type
* current_session_id

Supervisor window reuse allowed.

---

# 7) Posting legs (double-entry)

Reversal posting must:

* Mirror original posting batch
* Swap debit/credit sides
* Use exact same amounts

### Example:

If original Deposit:

* Debit Cashbox 100
* Credit Customer Account 100

Reversal:

* Debit Customer Account 100
* Credit Cashbox 100

If original Withdrawal:

* Debit Customer 100
* Credit Cashbox 100

Reversal:

* Debit Cashbox 100
* Credit Customer 100

If original included fee:

* Fee income leg must be reversed as well.

---

# 8) Drawer/session impact

Reversal impacts the **current session drawer**, not the original session.

Example:

* Original withdrawal happened yesterday.
* Today teller reverses it.
* Cash must be returned to drawer today.

Session close math must reflect reversal impact in current session only.

---

# 9) Validation rules (blocking)

* Reason code required
* Memo required (non-empty; recommended min length)
* Original transaction must not already have a reversal (Phase 1 full reversal model)

Optional Phase 2:

* Partial reversal support (not included now)

---

# 10) Idempotency

Reversal POST includes `idempotency_key`.

Server must ensure:

* Duplicate submit does not create two reversal transactions.

---

# 11) Receipt requirements (WS-041)

Reversal receipt must include:

* New Ref #
* Timestamp
* “REVERSAL”
* Reverses Original Ref #
* Original type
* Original date/time
* Financial breakdown
* Reason code
* Memo
* Drawer before/after
* Supervisor stamp (mandatory)

Actions:

* Print Receipt
* Return to Dashboard (recommended default)
* New Transaction (optional)

Focus:

* Return to Dashboard

---

# 12) Ops visibility

Reversal must:

* Appear in OPS session detail
* Be clearly linked to original
* Show approval metadata
* Be included in teller activity totals

Original transaction detail should show:

* “Reversed by Ref #XXXX”

---

# 13) Hard control rules (non-negotiable)

* [ ] Reversal always requires approval
* [ ] Original transaction never modified
* [ ] Reversal creates new balanced posting batch
* [ ] Reversal links original ↔ reversal
* [ ] Reversal posts to current open session
* [ ] Drawer impact reflected in current session only
* [ ] Reason + memo required
* [ ] Idempotency enforced

---

# 14) Phase 1 Scope Decisions (Locked)

* Full reversal only (no partial reversal)
* No reversal time window restriction yet
* No auto-approval
* No silent reversals

---

## Teller Phase 1 Coverage Status

You now have formal contracts for:

* Session Open
* Session Close
* Deposit
* Withdrawal
* Transfer
* Check Cashing
* Bank Draft
* Bill Payment
* Misc Receipt
* Vault Transfer
* Reversal
