Locked: **B) Teller initiates; Supervisor approves.**

This is the correct operational balance for Phase 1.

Below is the finalized **Reversal Authorization & Workflow Contract** aligned with your Teller UI, Posting Engine, and audit model.

---

# Reversal Authorization Model (Phase 1)

## Core Principle

* Teller may **initiate** reversal request.
* Supervisor must **approve** before posting.
* Teller cannot self-approve.
* Reversal cannot post without supervisor credential validation.

---

# 1. Role Requirements

## Teller

* Permission: `transaction_reverse_initiate`
* Cannot bypass approval
* Cannot approve own reversal

## Supervisor

* Permission: `transaction_reverse_approve`
* Must authenticate in approval modal
* Must not be the initiating teller (recommended enforcement)

---

# 2. WS-040 Reversal Flow (Updated)

## Step 1 — Teller Initiates

Screen: `WS-040 Reverse Transaction`

Teller selects:

* Reversal reason (required)
* Memo (required)

Teller presses **Reverse**

System transitions to:

* Approval Required state

---

## Step 2 — Supervisor Approval Modal

Modal requires:

* Supervisor username (or ID)
* Supervisor password
* Optional approval note

Validation rules:

* Must have `transaction_reverse_approve`
* Must not equal initiating teller
* Credentials validated
* Session active

If denied:

* Return focus to Reverse button
* No posting

If approved:

* Modal closes
* Reverse proceeds immediately to posting

---

# 3. Posting Behavior

After approval:

* System creates reversal transaction
* Links original + reversal
* Logs:

  * `initiated_by_user_id`
  * `approved_by_user_id`
  * `approval_timestamp`
  * `reversal_reason_code`
  * `memo`
* Uses server timestamp

Then displays WS-041 receipt block.

---

# 4. Audit Trail Requirements

Each reversal must store:

* Original transaction ID
* Reversal transaction ID
* Initiator ID
* Approver ID
* Initiation timestamp
* Approval timestamp
* Posting timestamp
* Reason code
* Memo
* IP/workstation ID (recommended)

No field editable after post.

---

# 5. Drawer Impact Logic (Reversal)

If original had cash impact:

* Reversal impacts **current open session drawer**
* Drawer footer must preview impact before approval
* After post, drawer totals update

If no session open:

* Blocking error (reversal requires active session)

---

# 6. UI State Model

## Before approval

Badge:

```
[ APPROVAL REQUIRED ]
```

## During posting

```
[ POSTING ]
```

## After success

Receipt block:

```
REVERSAL POSTED
Ref #: R-00012345
Reverses: W-00012344
Supervisor: S002
```

Focus: “New Transaction”

---

# 7. Edge Cases You Must Handle

| Scenario                                                        | Behavior                |
| --------------------------------------------------------------- | ----------------------- |
| Teller attempts to reverse own reversal                         | Block                   |
| Supervisor tries to approve own transaction (if they initiated) | Block                   |
| Supervisor times out mid-approval                               | Return to Reverse state |
| Session closed before approval                                  | Block and show error    |
| Transaction already reversed                                    | Block                   |

---

# 8. Permission Matrix (Phase 1 Minimal)

| Permission                 | Teller | Supervisor           |
| -------------------------- | ------ | -------------------- |
| Initiate reversal          | ✔      | ✔                    |
| Approve reversal           | ✖      | ✔                    |
| Reverse vault transfer     | ✔      | ✔ (approve required) |
| Reverse session open/close | ✖      | ✖                    |

---

# 9. Why This Is Clean Architecturally

* Keeps transaction control with teller
* Keeps authority control with supervisor
* Prevents silent correction
* Keeps immutable ledger intact
* Keeps UI contract consistent (approval modal model reused)

---

You now have:

* Full Phase 1 WS screen set
* Vault transfer finalized
* Any-time reversal policy
* Two-party reversal authorization model
* Ops visibility alignment
* Drawer/session integrity preserved

---

Next architectural lock that will affect everything:

Do you want approval modals (reversal, large withdrawal, vault threshold) to:

A) Re-authenticate supervisor every time
B) Allow supervisor “session approval window” (e.g., 5 minutes)
C) Require smart-card / MFA later but simple password now

This determines how your approval infrastructure is built.
