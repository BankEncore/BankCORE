# 1️⃣ Field-Level Permission Matrix

*(Who can override what — Phase 1 control-grade)*

## Legend

* ✓ = Allowed without approval
* A = Allowed but requires supervisor approval
* ✗ = Not allowed
* — = Not applicable

Roles assumed:

* **Teller**
* **Supervisor**
* **Head Teller**
* **Ops User**
* **Admin**

---

## A. Monetary Overrides

| Action / Field                           | Teller | Supervisor | Head Teller | Ops User | Admin |
| ---------------------------------------- | ------ | ---------- | ----------- | -------- | ----- |
| Fee override (any workflow)              | A      | ✓          | ✓           | ✗        | ✓     |
| Overdraft override (Withdrawal/Transfer) | A      | ✓          | ✓           | ✗        | ✓     |
| Insufficient funds override              | A      | ✓          | ✓           | ✗        | ✓     |
| Deposit hold override                    | A      | ✓          | ✓           | ✗        | ✓     |
| Cash over limit (Withdrawal)             | A      | ✓          | ✓           | ✗        | ✓     |
| Draft amount over threshold              | A      | ✓          | ✓           | ✗        | ✓     |
| Vault transfer over threshold            | A      | ✓          | ✓           | ✗        | ✓     |
| Session close variance over tolerance    | ✗      | ✓          | ✓           | ✗        | ✓     |

**Key rule:**
Teller can *initiate* overrides but cannot finalize them without approval.

---

## B. Control & Risk Fields

| Action / Field                         | Teller | Supervisor | Head Teller | Ops User | Admin |
| -------------------------------------- | ------ | ---------- | ----------- | -------- | ----- |
| Reversal initiation                    | ✓      | ✓          | ✓           | ✗        | ✓     |
| Reversal approval                      | ✗      | ✓          | ✓           | ✗        | ✓     |
| Manual draft serial entry override     | A      | ✓          | ✓           | ✗        | ✓     |
| Non-customer check cashing             | A      | ✓          | ✓           | ✗        | ✓     |
| After-hours transaction override       | A      | ✓          | ✓           | ✗        | ✓     |
| GL category sensitive (Misc Receipt)   | A      | ✓          | ✓           | ✗        | ✓     |
| Modify session opening cash after open | ✗      | ✗          | ✗           | ✗        | ✗     |
| Modify closed session                  | ✗      | ✗          | ✗           | ✗        | ✗     |

---

## C. Visibility / Scope Controls

| Capability                               | Teller | Supervisor | Head Teller | Ops User       | Admin |
| ---------------------------------------- | ------ | ---------- | ----------- | -------------- | ----- |
| View own session receipts                | ✓      | ✓          | ✓           | ✗              | ✓     |
| View other teller session receipts (Ops) | ✗      | ✓          | ✓           | ✓              | ✓     |
| View multi-branch activity               | ✗      | ✗          | ✗           | ✓ (if granted) | ✓     |

---

# 2️⃣ Approval-Type × Role Mapping

*(Who may approve each approval type)*

All approvals use the same modal and window lifecycle.

---

## A. Transaction Approvals

| Approval Type              | Teller | Supervisor | Head Teller | Admin |
| -------------------------- | ------ | ---------- | ----------- | ----- |
| withdrawal_over_limit      | ✗      | ✓          | ✓           | ✓     |
| withdrawal_cash_over_limit | ✗      | ✓          | ✓           | ✓     |
| overdraft_override         | ✗      | ✓          | ✓           | ✓     |
| transfer_over_limit        | ✗      | ✓          | ✓           | ✓     |
| deposit_over_limit         | ✗      | ✓          | ✓           | ✓     |
| deposit_check_over_limit   | ✗      | ✓          | ✓           | ✓     |
| deposit_hold_override      | ✗      | ✓          | ✓           | ✓     |
| draft_over_limit           | ✗      | ✓          | ✓           | ✓     |
| draft_cash_over_limit      | ✗      | ✓          | ✓           | ✓     |
| bill_payment_over_limit    | ✗      | ✓          | ✓           | ✓     |
| misc_receipt_over_limit    | ✗      | ✓          | ✓           | ✓     |
| check_cashing_over_limit   | ✗      | ✓          | ✓           | ✓     |
| check_cashing_non_customer | ✗      | ✓          | ✓           | ✓     |
| vault_transfer_over_limit  | ✗      | ✓          | ✓           | ✓     |

---

## B. Control & Session Approvals

| Approval Type            | Teller | Supervisor | Head Teller | Admin |
| ------------------------ | ------ | ---------- | ----------- | ----- |
| transaction_reversal     | ✗      | ✓          | ✓           | ✓     |
| session_close_over_short | ✗      | ✓          | ✓           | ✓     |
| fee_override             | ✗      | ✓          | ✓           | ✓     |
| after_hours_override     | ✗      | ✓          | ✓           | ✓     |
| sensitive_gl_override    | ✗      | ✓          | ✓           | ✓     |

---

# 3️⃣ Non-Delegable Rules (Hard Controls)

| Rule                                           | Enforced |
| ---------------------------------------------- | -------- |
| Initiator cannot approve own action            | ✓        |
| Approval window tied to workstation + session  | ✓        |
| Lock/logout invalidates approval window        | ✓        |
| Closed session cannot be modified              | ✓        |
| Reversal always requires approval              | ✓        |
| All approvals logged with initiator + approver | ✓        |

---

# 4️⃣ Minimal Phase 1 Permission Flags (Implementation-Friendly)

Rather than relying purely on roles, map approval types to flags:

### Transaction permissions

* `transact.deposit`
* `transact.withdrawal`
* `transact.transfer`
* `transact.check_cashing`
* `transact.draft`
* `transact.bill_payment`
* `transact.misc_receipt`
* `transact.vault`

### Override initiation permissions

* `override.fee`
* `override.overdraft`
* `override.hold`
* `override.after_hours`
* `override.sensitive_gl`

### Approval permissions

* `approve.transaction`
* `approve.reversal`
* `approve.session_variance`
* `approve.vault`
* `approve.override`

### Reporting

* `ops.view_reports`
* `ops.view_sessions`

This structure allows:

* granular escalation
* future branch-level override restrictions
* easy Pundit policy mapping

