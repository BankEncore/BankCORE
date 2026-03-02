# BankCORE Action Terminology Standard

Purpose: Standardize verbs and labels used for buttons, links, menus, approvals, and destructive actions across Teller, Ops, and CSR workspaces.

This prevents:

- Synonym drift (Save vs Submit vs Complete vs Post)  
- Inconsistent approval language  
- Ambiguous destructive actions  
- UX confusion in regulated workflows

All new UI must use these canonical verbs.

---

# 1\) Core Commit Vocabulary (Financial)

These verbs are reserved and must not be substituted.

## 1.1 Post

Definition: Finalize and create immutable financial postings.

Use for:

- Post Deposit  
- Post Withdrawal  
- Post Transfer  
- Post Batch

Never use:

- Save  
- Submit  
- Complete  
- Confirm

“Post” means money moved and ledger affected.

---

## 1.2 Void

Definition: Cancel a transaction before settlement or finalization.

Use for:

- Void Transaction  
- Void Item

Never use:

- Cancel (for financial reversal)  
- Delete

Void is financial and auditable.

---

## 1.3 Reverse

Definition: Create an offsetting transaction after posting.

Use for:

- Reverse Transaction  
- Reverse Fee

Never use:

- Undo  
- Rollback

Reverse creates a new ledger event.

---

## 1.4 Request Approval

Definition: Submit transaction for supervisor authorization.

Use for:

- Request Approval

Never use:

- Submit for Review  
- Ask Supervisor

---

## 1.5 Approve / Decline

Supervisor-only verbs.

Use exactly:

- Approve  
- Decline

Never use:

- Accept  
- Reject  
- Authorize (unless used in policy context)

---

# 2\) Workflow (Non-Final) Actions

## 2.1 Save Draft

Definition: Persist progress without financial posting.

Use only when:

- Work is incomplete  
- Transaction not yet posted

Never use:

- Save (alone)  
- Store

---

## 2.2 Continue

Definition: Proceed to next step in multi-step workflow.

Use for:

- Continue

Not:

- Next  
- Proceed

---

## 2.3 Cancel

Definition: Exit current workflow without committing.

Use for:

- Cancel

Cancel is navigation, not destruction.

Never use:

- Abort  
- Stop  
- Close (when workflow is in progress)

---

# 3\) Navigation Actions

## 3.1 Back

Return to previous list or parent view.

Use:

- Back to Accounts  
- Back to Teller Dashboard

---

## 3.2 Close

Close modal or panel.

Not used for:

- Canceling transactions  
- Voiding financial activity

---

# 4\) Record Management

## 4.1 New

Create new record.

Use:

- New Account  
- New Party  
- New Batch

Not:

- Add (for full record creation)

---

## 4.2 Add

Add sub-item within context.

Use:

- Add Check  
- Add Fee  
- Add Note

Not:

- New Check (inside transaction)

---

## 4.3 Edit

Modify existing record.

Never use:

- Update (as button label)

---

## 4.4 Delete

Permanent removal of non-financial record.

Use for:

- Delete Note  
- Delete Attachment

Never use:

- Remove (unless removing sub-line item)

---

## 4.5 Remove

Detach or remove sub-item in current context.

Use for:

- Remove Fee  
- Remove Check

---

# 5\) Utility Actions

## 5.1 Print

Print receipt or report.

Not:

- Generate Print  
- Create Receipt

---

## 5.2 Export

Export data (CSV, PDF, etc.)

---

## 5.3 View

Open read-only detail.

Not:

- Open  
- Inspect

---

## 5.4 Copy

Copy to clipboard.

---

# 6\) State Indicators (Badge Terminology)

Use consistent states:

- Active  
- Closed  
- Pending Approval  
- Approved  
- Declined  
- Reversed  
- Voided  
- Restricted  
- On Hold  
- Out of Balance

Avoid:

- Waiting  
- Processing  
- In Progress (except active transaction context)

---

# 7\) Prohibited Language

Never use:

- OK  
- Yes  
- Go  
- Confirm (for financial commit)  
- Done  
- Finish (unless final step of non-financial wizard)  
- Undo  
- Retry (use Reattempt or Reprocess if required)

---

# 8\) Teller-Specific Conventions

Teller financial commit button must always be:

Post 

Examples:

- Post Deposit  
- Post Withdrawal  
- Post Transfer

Supervisor action:

Approve Decline

Void and Reverse must always include object:

- Void Transaction  
- Reverse Deposit

---

# 9\) Audit & Compliance Language

Language must reflect:

- Intentional action  
- Explicit financial movement  
- Clear state transition

Every verb should clearly answer:

"What exactly is happening to the money?"

If the answer is unclear, the verb is wrong.

---

# 10\) Enforcement

New screens must:

- Use canonical verbs from this document  
- Avoid introducing synonyms  
- Preserve financial/legal clarity  
- Match Actions Contract placement rules

Terminology consistency is a control mechanism, not a cosmetic preference.  