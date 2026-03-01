## L2-WF-03 — Receipt Rendering & Print Contract

**Status:** **Fits but needs working changes** — receipt direction aligns, but this document assumes additional workflows and reversal-linked behavior not yet implemented.
**Current Implementation Mapping:** Implemented receipt surface is `GET /teller/receipts/:request_id` plus post-success receipt panel in teller transaction pages.

---

# 1) Receipt delivery model

## 1.1 Where receipts render

* In Workstation (`/teller/*`), successful post replaces the entry form region with a **Receipt Block** (inline).
* Receipt Block is the canonical “posted” UI state.

## 1.2 Actions (only two)

* **Print Receipt**
* **New <Transaction>** (manual reset)

No other actions appear inside the receipt block.

---

# 2) Receipt types in Phase 1

Each of these produces a receipt block:

* Deposit (WS-200)
* Withdrawal (WS-210)
* Transfer (WS-220)
* Check Cashing (WS-230)
* Bank Draft (WS-240)
* Bill Payment (WS-250)
* Misc Receipt (WS-260)
* Vault Transfer (WS-300)
* Reversal (WS-041 / also used after WS-040 post)
* Session Open (WS-110 confirmation)
* Session Close (WS-120 close report)

---

# 3) Receipt layout (standard sections)

Receipts are rendered in a consistent structure:

1. **Header**
2. **Context line**
3. **Reference & timestamps**
4. **Transaction details**
5. **Drawer impact**
6. **Approval stamp (conditional)**
7. **Footer**

### 3.1 Header (always)

* BankCORE
* Transaction name (e.g., WITHDRAWAL, VAULT TRANSFER, REVERSAL)

### 3.2 Context line (always)

* Branch code
* Workstation code
* Teller ID (user)
* Session ID

### 3.3 Reference & timestamps (always)

* Receipt reference # (server generated)
* Posted timestamp (server time)

### 3.4 Transaction details (always)

Must include:

* Account reference(s) masked (last 4) + name if known
* Line-item breakdown relevant to transaction type
* Totals summary

### 3.5 Drawer impact (conditional)

* If cash movement: show **Drawer Before / Change / Drawer After**
* If no cash movement: show `NO CASH MOVEMENT`

### 3.6 Approval stamp (conditional)

If approval used:

* Supervisor ID
* Approval timestamp
* Indicate “window used” **in audit only** (optional to display)

### 3.7 Footer (always)

* “Customer Copy” / “Bank Copy” indicator if you want dual-print later (optional)
* Standard disclaimer line(s) (short)

---

# 4) Required receipt fields by transaction

## 4.1 Deposit

* Account credited
* Cash in
* Checks in (list)
* Total deposit
* Holds applied (if any)

## 4.2 Withdrawal

* Account debited
* Cash out / draft out / mixed (with breakdown)
* Fee (if any)
* Total debit

## 4.3 Transfer

* From account
* To account
* Amount
* Memo (optional)
* `NO CASH MOVEMENT`

## 4.4 Check Cashing

* Check amount
* Fee (if any)
* Cash paid out
* Check identifier fields (check #; optionally routing/micr if captured)

## 4.5 Bank Draft

* Funding account
* Draft amount
* Fee
* Draft serial/reference (if issued)

## 4.6 Bill Payment

* Funding account
* Payee
* Amount
* Fee (if any)
* Confirmation/reference

## 4.7 Misc Receipt

* Source (classification)
* Amount
* Memo/description
* Cash impact (if any)

## 4.8 Vault Transfer

* Direction (Drawer→Vault or Vault→Drawer)
* Amount
* Reason code label
* Memo (if present)

## 4.9 Reversal

Must include linkage:

* Reversal ref #
* Reverses original ref #
* Original posted date/time
* Original teller/session (if available)
* Reversal reason + memo (required)
* Supervisor stamp (required)

## 4.10 Session Open

* Session ID
* Opened timestamp
* Opening cash

## 4.11 Session Close

* Session ID
* Opened/closed timestamps
* Expected closing cash
* Counted closing cash
* Over/short
* Supervisor stamp if variance required approval

---

# 5) Print contract

## 5.1 Print action behavior

* `Print Receipt` triggers `window.print()`
* Receipt block must have a print-only stylesheet scope, so only the receipt prints.

## 5.2 Print CSS requirements

* Hide workstation chrome (top bar, command bar, nav)
* Print only receipt content
* Use tabular numerals for amounts
* Avoid color reliance (monochrome safe)
* Ensure line lengths fit:

  * primary: 80mm thermal feel (narrow)
  * secondary: letter/A4 acceptable without wrapping errors

## 5.3 Print layout rules

* Fixed-width feel is optional, but amounts must align:

  * label left, amount right
* No orphan headers
* Avoid page breaks mid-summary (use `page-break-inside: avoid` on receipt sections)

---

# 6) Receipt data source contract

Receipt content must be derived from:

* teller transaction record
* posting batch summary
* approval record (if used)
* session snapshot (drawer before/after)

No client-computed totals should be trusted for receipt.

---

# 7) Idempotency & receipt retrieval

If a post is replayed with same idempotency key:

* Server must return the same receipt reference and content.

Optional dedicated receipt route:

* `GET /teller/transactions/:id/receipt` (read-only)
* used for WS-031 viewer and WS-030 reprint

---

# 8) Acceptance checklist

* [ ] Every post ends in a receipt block with only Print + New actions
* [ ] Receipt always includes reference # + server timestamp + context line
* [ ] Drawer impact shown or “NO CASH MOVEMENT” shown
* [ ] Approval stamp shown when approval used
* [ ] Reversal receipt includes original linkage + reason/memo + supervisor
* [ ] Print hides all non-receipt UI and prints cleanly
* [ ] Receipt content is server-authoritative (no client math)
