# Phase 1 Permission Matrix

**Roles × Screens × Actions**

## Role Definitions (Phase 1)

| Role            | Description                                    |
| --------------- | ---------------------------------------------- |
| **Teller**      | Performs transactions within workstation shell |
| **Supervisor**  | Approves transactions and session variances    |
| **Head Teller** | Teller + elevated cash control authority       |
| **Ops User**    | Read-only reporting and inspection             |
| **Ops Manager** | Ops + elevated reporting scope                 |
| **Admin**       | System configuration and full access           |

---

# 1️⃣ Workstation Shell (`/teller/*`)

## A. Context & Session Control

| Screen / Action            | Teller                  | Supervisor | Head Teller | Ops User | Admin |
| -------------------------- | ----------------------- | ---------- | ----------- | -------- | ----- |
| WS-005 Context Gate        | ✓                       | ✓          | ✓           | ✗        | ✓     |
| WS-015 Lock/Unlock         | ✓ (own)                 | ✓ (own)    | ✓           | ✗        | ✓     |
| WS-110 Open Session        | ✓                       | ✓          | ✓           | ✗        | ✓     |
| WS-120 Close Session       | ✓                       | ✓          | ✓           | ✗        | ✓     |
| Close w/ variance approval | ✗ (cannot self-approve) | ✓          | ✓           | ✗        | ✓     |

---

## B. Transaction Workflows

| Workflow       | Teller | Supervisor | Head Teller | Ops User | Admin |
| -------------- | ------ | ---------- | ----------- | -------- | ----- |
| Deposit        | ✓      | ✓          | ✓           | ✗        | ✓     |
| Withdrawal     | ✓      | ✓          | ✓           | ✗        | ✓     |
| Transfer       | ✓      | ✓          | ✓           | ✗        | ✓     |
| Check Cashing  | ✓      | ✓          | ✓           | ✗        | ✓     |
| Bank Draft     | ✓      | ✓          | ✓           | ✗        | ✓     |
| Bill Payment   | ✓      | ✓          | ✓           | ✗        | ✓     |
| Misc Receipt   | ✓      | ✓          | ✓           | ✗        | ✓     |
| Vault Transfer | ✓      | ✓          | ✓           | ✗        | ✓     |

**Notes**

* Supervisor and Head Teller can transact only if also assigned teller capability.
* Ops roles cannot transact.

---

## C. Approval Actions

| Action                     | Teller | Supervisor | Head Teller | Ops User | Admin |
| -------------------------- | ------ | ---------- | ----------- | -------- | ----- |
| Approve Transaction        | ✗      | ✓          | ✓           | ✗        | ✓     |
| Approve Session Over/Short | ✗      | ✓          | ✓           | ✗        | ✓     |
| Approve Vault Transfer     | ✗      | ✓          | ✓           | ✗        | ✓     |
| Approve Reversal           | ✗      | ✓          | ✓           | ✗        | ✓     |
| Self-Approval              | ✗      | ✗          | ✗           | ✗        | ✗     |

**Hard Rule:**
No user may approve their own initiated transaction.

---

## D. Reversal

| Action            | Teller | Supervisor | Head Teller | Ops User | Admin |
| ----------------- | ------ | ---------- | ----------- | -------- | ----- |
| Initiate Reversal | ✓      | ✓          | ✓           | ✗        | ✓     |
| Approve Reversal  | ✗      | ✓          | ✓           | ✗        | ✓     |

Reversal is **always approval-required**.

---

## E. Receipt & Activity

| Screen / Action        | Teller          | Supervisor | Head Teller | Ops User    | Admin |
| ---------------------- | --------------- | ---------- | ----------- | ----------- | ----- |
| WS-030 Recent Activity | ✓ (own session) | ✓          | ✓           | ✗           | ✓     |
| WS-031 Receipt Viewer  | ✓ (own session) | ✓          | ✓           | ✗           | ✓     |
| Reprint Receipt        | ✓               | ✓          | ✓           | ✓ (via Ops) | ✓     |

---

# 2️⃣ Ops Shell (`/ops/*`)

## A. Reports & Search

| Screen                    | Teller | Supervisor | Head Teller | Ops User | Ops Manager | Admin |
| ------------------------- | ------ | ---------- | ----------- | -------- | ----------- | ----- |
| OPS-010 Teller Activity   | ✗      | ✓          | ✓           | ✓        | ✓           | ✓     |
| OPS-020 Session Search    | ✗      | ✓          | ✓           | ✓        | ✓           | ✓     |
| OPS-030 Session Detail    | ✗      | ✓          | ✓           | ✓        | ✓           | ✓     |
| View Receipts (read-only) | ✗      | ✓          | ✓           | ✓        | ✓           | ✓     |

---

## B. Scope Control (Data Visibility)

| Capability             | Supervisor | Ops User    | Ops Manager    | Admin |
| ---------------------- | ---------- | ----------- | -------------- | ----- |
| View own branch only   | ✓          | ✓ (default) | ✗              | ✗     |
| View multiple branches | ✗          | ✗           | ✓              | ✓     |
| View all branches      | ✗          | ✗           | ✓ (if granted) | ✓     |

---

# 3️⃣ Control Separation Summary

### Separation of Duties (SoD)

| Control                                        | Enforced |
| ---------------------------------------------- | -------- |
| Teller cannot approve own transaction          | ✓        |
| Teller cannot approve own reversal             | ✓        |
| Teller cannot approve session variance         | ✓        |
| Ops cannot transact                            | ✓        |
| Workstation actions not available in Ops shell | ✓        |

---

# 4️⃣ Recommended Permission Flags (Pundit-friendly)

Rather than hard-coding by role name, use permission flags:

* `teller.transact`
* `teller.open_session`
* `teller.close_session`
* `teller.reverse`
* `approval.transaction`
* `approval.reversal`
* `approval.session_variance`
* `approval.vault`
* `ops.view_reports`
* `ops.view_sessions`
* `ops.multi_branch`
* `admin.full_access`

This makes your matrix role-agnostic and future-proof.

---

# 5️⃣ High-Risk Actions (Require Explicit Permission Flag)

These should never be implied by generic role:

* Reversal initiation
* Vault transfer
* Fee override
* Overdraft override
* Session variance approval
* Draft issuance above threshold

---

# 6️⃣ Phase 1 Minimal Role Bundles (Suggested)

### Teller

* `teller.transact`
* `teller.open_session`
* `teller.close_session`
* `teller.reverse`

### Supervisor

* All Teller permissions +
* `approval.*`
* `ops.view_reports`
* `ops.view_sessions`

### Ops User

* `ops.view_reports`
* `ops.view_sessions`

### Admin

* All permissions
