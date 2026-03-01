Understood. Below is the **formal feature requirement specification for the Advisory system itself** (not the decision guide).

---

# Feature Requirement

# Customer Advisory System (Party & Account Scoped)

---

# 1. Purpose

The Customer Advisory system provides a structured, auditable mechanism for communicating operational, compliance, legal, and fraud-related information related to:

* Parties (CIF entities)
* Accounts

The system enables risk communication and transaction control enforcement within Teller and CSR workspaces.

The system must support:

* Informational documentation
* Risk signaling
* Controlled acknowledgment workflows
* Transaction restrictions

---

# 2. Scope

This feature applies to:

* Teller workspace
* CSR workspace
* Party record screens
* Account record screens
* Transaction posting flows

Advisories are manually created and maintained in this iteration.

---

# 3. Core Functional Requirements

---

## 3.1 Advisory Object

The system shall support creation of an Advisory record with the following required attributes:

### Core Fields

* Scope Type (Party or Account)
* Scope ID
* Category
* Title (short summary)
* Body (long-form text)
* Severity
* Effective Start Date
* Effective End Date (nullable)
* Workspace Visibility (Teller, CSR, Both)
* Pinned (boolean)

### System Fields

* Created By
* Created At
* Updated By
* Updated At
* Active (system-calculated)
* Acknowledgment tracking (if applicable)

---

## 3.2 Severity Levels

The system shall support the following severity levels:

| Level | Name                    | Behavior                           |
| ----- | ----------------------- | ---------------------------------- |
| 0     | Record                  | Visible on record screens only     |
| 1     | Notice                  | Passive informational display      |
| 2     | Alert                   | Prominent non-blocking display     |
| 3     | Requires Acknowledgment | Blocking modal before continuation |
| 4     | Restriction             | Hard stop — transaction prohibited |

Severity determines runtime behavior.

---

# 4. Runtime Behavior

---

## 4.1 Activation Rules

An advisory is considered **Active** if:

* Current date ≥ effective_start_date
* Current date ≤ effective_end_date (if present)
* Not manually deactivated
* Not expired

---

## 4.2 Display Rules — Record Screens

Party and Account record pages shall:

* Include an “Advisories” tab
* Display all advisories (active and inactive)
* Default filter:

  * Active only
  * Pinned first
  * Severity descending
  * Newest first

Table must support sorting and filtering by:

* Category
* Severity
* Created By
* Date
* Active Status

---

## 4.3 Display Rules — Workstation Context

When a Party or Account is selected in:

* Teller workspace
* CSR workspace

The system shall evaluate active advisories and behave as follows:

---

### Severity 0 — Record

* Not displayed in transaction shell.
* Only on record screens.

---

### Severity 1 — Notice

* Display in reference panel.
* Non-blocking.
* Muted styling.

---

### Severity 2 — Alert

* Prominent banner in reference panel.
* Non-blocking.
* Must remain visible while entity selected.

---

### Severity 3 — Requires Acknowledgment

When entity selected or transaction attempted:

* Display blocking modal.
* User must select:

  * “Acknowledge & Continue”
  * “Cancel”

System must log:

* user_id
* workstation_id
* teller_session_id (if applicable)
* timestamp

Acknowledgment shall suppress repeat prompt for that user/session unless advisory updated.

---

### Severity 4 — Restriction

When entity selected or transaction attempted:

* Display hard-stop message.
* Prevent transaction submission.
* Disable posting engine invocation.
* Provide navigation options (e.g., change selection).

No bypass allowed in this iteration.

---

# 5. Posting Enforcement

Immediately prior to transaction commit:

* System must re-check for active Severity 3 and 4 advisories.
* If Severity 4 present → block.
* If Severity 3 present and not acknowledged → require acknowledgment.
* This check must occur server-side.

Fail-open behavior is not permitted.

---

# 6. Acknowledgment Model

Severity 3 advisories shall support per-user acknowledgment.

Acknowledgment record shall include:

* advisory_id
* user_id
* workstation_id
* teller_session_id
* acknowledged_at

Advisory edits after acknowledgment shall reset acknowledgment state.

---

# 7. Permissions

The system shall enforce:

* Only authorized roles may create/edit advisories.
* Only supervisor/compliance roles may assign:

  * Severity 3
  * Severity 4
* Downgrading severity requires elevated role.

---

# 8. Governance & Audit

All advisory lifecycle events must be logged:

* Created
* Edited
* Severity changed
* Effective dates changed
* Deactivated
* Acknowledged

Restriction advisories must support structured reason code (if applicable).

---

# 9. Non-Functional Requirements

* Must not degrade transaction response time.
* Must be deterministic.
* Must not rely solely on client-side validation.
* Must support future automation expansion.

---

# 10. Acceptance Criteria

1. User can create Advisory on Party or Account.
2. Advisory appears in record tab.
3. Advisory enforces severity behavior correctly in Teller workspace.
4. Posting attempt re-check enforces Severity 3 and 4.
5. Acknowledgment logs correctly.
6. Restriction prevents posting.
7. Advisory expiration automatically deactivates display.

---

# 11. Out of Scope (Current Iteration)

* Automated advisory generation
* Supervisor override workflow
* Global/system-wide advisories
* External compliance integration
* Customer-facing notification

---

# 12. Control Objective

The Advisory system functions as:

* A risk communication mechanism
* A preventive control (Severity 4)
* A documented acknowledgment control (Severity 3)
* An auditable operational messaging framework

It supports transaction integrity and regulatory defensibility.

--


# 1. Terminology Standardization

Avoid “notes” (too informal) and use structured language.

## Recommended Term: **Customer Advisory**

You can implement as:

```
Advisory
```

Subtype determined by severity.

---

## Severity Levels (replace Record / Informational / Alert / Warning / Block)

Use regulator-friendly, control-oriented language:

| Level | System Name                 | Teller Behavior                    | Transaction Impact                 |
| ----- | --------------------------- | ---------------------------------- | ---------------------------------- |
| 0     | **Record**                  | Visible only on record screens     | None                               |
| 1     | **Notice**                  | Passive inline banner in workspace | None                               |
| 2     | **Alert**                   | Prominent banner in workspace      | None                               |
| 3     | **Requires Acknowledgment** | Modal acknowledgment required      | Must acknowledge before proceeding |
| 4     | **Restriction**             | Hard stop                          | Transaction blocked                |

**Why this works better:**

* “Warning” can imply liability.
* “Block” is technically vague; “Restriction” implies a defined control.
* “Requires Acknowledgment” clarifies workflow behavior.

---

# 2. Object Scope Model

Advisories may attach to:

* Party
* Account
* Both (future-proof)
* System (global, optional later)

Recommended association model:

```
Advisory
  advisory_scope_type (Party | Account)
  advisory_scope_id
```

---

# 3. Advisory Classification Model

Each advisory should include:

### Core Fields

* Category (Fraud, Compliance, Relationship, Operational, Legal, etc.)
* Title (short summary)
* Body (long form text)
* Severity (enum)
* Workspace Visibility

  * Teller
  * CSR
  * Both
* Effective Start Date
* Effective End Date (nullable)
* Pinned (boolean)
* Active (system-calculated based on dates + acknowledgment + restriction state)
* Created By
* Created At
* Last Updated By
* Acknowledged By (nullable)
* Acknowledged At (nullable)
* Restriction Code (if severity = Restriction)

---

# 4. Behavioral Refinement (Critical Section)

## A. Activation Logic

Advisory is **Active** if:

```
current_date between effective_start and effective_end (or end null)
AND not acknowledged (if acknowledgment required)
AND not manually deactivated
```

Restriction advisories should not deactivate automatically via acknowledgment unless explicitly allowed.

---

## B. Teller Workspace Behavior

### 1. Record (Severity 0)

* Visible only on Party/Account detail screens.
* No teller workflow interruption.

### 2. Notice (Severity 1)

* Small, muted banner in right-hand reference panel.
* No workflow interruption.

### 3. Alert (Severity 2)

* Prominent colored banner.
* Appears when party/account selected.
* No interruption.

### 4. Requires Acknowledgment (Severity 3)

* Blocking modal.
* Must click:

  * “Acknowledge & Continue”
* System logs:

  * user_id
  * workstation_id
  * teller_session_id
  * timestamp

Should NOT allow bypass without acknowledgment.

### 5. Restriction (Severity 4)

* Hard block.
* Disables transaction posting.
* Message displayed in red panel.
* Supervisor override optional (future feature).

---

# 5. Acknowledgment Model Clarification

Important refinement:

Acknowledgment should be one of two models:

### Option A – Global Acknowledgment (Simpler MVP)

Once acknowledged → becomes inactive for all users.

### Option B – Per-User Acknowledgment (More robust)

Track acknowledgment per user/session.
Advisory remains active but does not re-trigger for that user.

For regulated environments, **Option B is safer**.

---

# 6. Pinned Behavior Clarification

Pinned should not override severity.

Sort order recommendation:

```
1. Restriction
2. Requires Acknowledgment
3. Alert
4. Notice
5. Record
Within each:
  - Pinned first
  - Newest first
```

Pinned = display priority, not severity escalation.

---

# 7. Table View (Record Screens)

Default Filters:

* Active = true
* Pinned first
* Severity desc
* Created_at desc

Sortable columns:

* Effective Date
* Category
* Severity
* Created By
* Active Status
* Acknowledged Status

---

# 8. Governance / Audit Enhancements (Strongly Recommended)

Add:

* Advisory Audit Log

  * Created
  * Edited
  * Severity Changed
  * Expired
  * Acknowledged
  * Override (future)

This protects against:

* Improper removal of fraud flags
* Quiet downgrading of severity
* Retroactive modification

---

# 9. Regulatory Alignment Considerations

Ensure ability to support:

* OFAC watchlist flags
* Deceased customer flags
* Bankruptcy restrictions
* Legal hold
* Account freeze
* Internal fraud monitoring

For these, use **Restriction** severity with:

```
restriction_code (enum)
```

Example:

* ACCOUNT_FROZEN
* FRAUD_SUSPECTED
* LEGAL_HOLD
* DO_NOT_TRANSACT

---

# 10. Suggested Naming Summary

Replace:

| Current Term  | Recommended                    |
| ------------- | ------------------------------ |
| Note          | Advisory                       |
| Alert         | Alert (keep as severity level) |
| Warning       | Requires Acknowledgment        |
| Block         | Restriction                    |
| Informational | Notice                         |
| Record        | Record                         |

---

# 11. Clean Final Model Concept

```
Advisory
  id
  scope_type (Party, Account)
  scope_id
  category
  title
  body
  severity (0–4)
  workspace_visibility (bitmask or enum set)
  effective_start_at
  effective_end_at
  pinned
  active_override (nullable)
  restriction_code (nullable)
  created_by_id
  updated_by_id
  created_at
  updated_at
```

Optional:

```
AdvisoryAcknowledgment
  advisory_id
  user_id
  teller_session_id
  acknowledged_at
```

---

# 12. Design Direction Recommendation

Keep terminology consistent across the system:

* UI label: **Advisories**
* Button: “Add Advisory”
* Banner header: “Customer Advisory”
* Table tab: “Advisories”

Avoid mixing:

* Notes
* Messages
* Alerts
* Flags

Consistency reduces operational confusion.

--

# Workstation UI Interaction Contract — Advisories

Scope: **Teller + CSR workstation shells** when a **Party** or **Account** is selected, viewed, or used for posting. Terminology: **Advisory** with **Severity** levels:
0 Record, 1 Notice, 2 Alert, 3 Requires Acknowledgment, 4 Restriction.

---

## 1. Interaction Surfaces

### A. **Reference Panel (Right Column)**

Always present when an entity is selected.

* Shows **top 0–3 active advisories** (by sort rules below).
* Includes **“View all advisories”** link.

### B. **Gate Modal (Blocking)**

Used only for:

* Severity **3 Requires Acknowledgment**
* Severity **4 Restriction** (hard stop panel/modal)

### C. **Record Screen Tab**

Party and Account record pages include an **Advisories** tab with full table.

---

## 2. Trigger Points

### T1 — Entity Selected (search result picked / account chosen)

System must fetch and evaluate **active advisories** for:

* Selected **Account**
* Selected **Party** (primary owner / linked party context if available)

### T2 — Entity Context Changes

Re-evaluate advisories when any of these change:

* Account changes
* Party changes
* Teller session changes
* Workspace changes (Teller ↔ CSR)
* Effective date boundary crosses midnight (optional: on page load only for MVP)

### T3 — Posting Attempt (Submit Transaction)

Hard re-check advisories **immediately before commit**:

* If **Restriction** exists → block
* If **Requires Ack** exists → require ack then allow continuation

---

## 3. Advisory Sort Order (Display Priority)

Across all lists and panels:

1. Severity desc: **Restriction → Requires Ack → Alert → Notice → Record**
2. Within severity: **Pinned first**
3. Then: **Effective_start_at desc** (or created_at desc as fallback)

Pinned affects *ordering only*, never overrides Severity.

---

## 4. Severity-Specific UX Behavior

## 0 — Record

* **Only** shown on record screen table/tab.
* Not shown in teller transaction shell reference panel.

## 1 — Notice

* Shown in reference panel as **muted line item**.
* No interruption.
* Optional “Details” expand/collapse inline.

## 2 — Alert

* Shown in reference panel as **prominent banner** (non-blocking).
* Must remain visible while entity selected.
* No required user action.

## 3 — Requires Acknowledgment

### When it triggers

* On **entity selection** (T1) **before** user can proceed, OR
* On **posting attempt** (T3) if user arrived via another path.

### UX

* Show **blocking modal** with:

  * Title: “Acknowledgment required”
  * Advisory title + body
  * Effective date range
  * Buttons:

    * Primary: **Acknowledge & Continue**
    * Secondary: **Cancel** (returns to prior screen; does not post)

### Rules

* If multiple “Requires Ack” advisories exist:

  * Show in **descending priority order**, user acknowledges each.
  * Provide “Next” flow; no skipping.

## 4 — Restriction

### When it triggers

* Immediately at **entity selection** (T1), and again at **posting attempt** (T3).

### UX

* Display **hard stop panel** (modal or full-width blocker):

  * Title: “Transaction restricted”
  * Advisory title + body
  * Restriction code (if present)
  * Allowed actions:

    * **Change Account/Party**
    * **Return to Dashboard**
    * Optional future: “Request Supervisor Override” (not MVP)

### Rules

* No acknowledgment path unless explicitly configured (generally not).
* Must prevent:

  * transaction submit
  * tender entry commit
  * posting engine invocation

---

## 5. Acknowledgment Semantics

Use **Per-User Acknowledgment** for workstation correctness:

### Ack token includes

* advisory_id
* user_id
* teller_session_id (if in Teller workspace)
* workstation_id
* acknowledged_at

### Ack effect

* Removes the advisory from blocking state **for that user** (and optionally session).
* Advisory remains active for others.

### Re-trigger rules (recommended)

* Re-trigger if:

  * new teller session
  * advisory content updated after ack (updated_at > acknowledged_at)
  * severity escalated

---

## 6. CSR Workspace Differences

CSR can be less interruptive **except**:

* Severity 3 and 4 remain blocking in CSR too (consistency and control).
* CSR reference panel shows up to **5** items (more review-oriented).

---

## 7. Data Fetch / Caching Contract

### Minimum behavior

* On entity selection: fetch advisories from server (no stale cache).
* On posting attempt: re-check server-side regardless of cached state.

### Optimization (allowed)

* Cache advisory list in-page for the selected entity.
* Must invalidate when entity changes.

---

## 8. UI Copy / Labels (Standard)

* Panel header: **Advisories**
* Table tab: **Advisories**
* Button: **Add Advisory**
* Modal buttons:

  * **Acknowledge & Continue**
  * **Cancel**
* Restriction CTA:

  * **Change selection**
  * **Return**

Avoid: “notes”, “flags”, “warnings” in UI labels.

---

## 9. Failure / Edge Cases

* If advisory fetch fails:

  * Treat as **fail-closed for posting** (block submit with “Unable to verify advisories”)
  * Allow navigation to record screen (read-only) if desired
* If advisory becomes effective mid-session:

  * Enforced at **posting attempt** (T3) re-check

---

## 10. Acceptance Criteria (Testable)

1. Selecting an account with a Restriction prevents entry and prevents posting.
2. Selecting an account with Requires Ack forces modal before continuing.
3. Acknowledging logs user/session/workstation and unblocks for that user.
4. Alerts and Notices show in reference panel without blocking.
5. Posting attempt re-check enforces newly-added Restriction/Requires Ack.
6. Table view supports sorting/filtering and shows all advisories regardless of visibility settings (unless permissions restrict).

---

## 11. Permissions (Workstation Controls)

Minimum roles:

* View advisories
* Create advisories
* Edit advisories
* Deactivate advisories
* View acknowledgments/audit trail (supervisor/compliance)

--

Below is a **structured decision tree + operator guidance** designed for internal staff creating Advisories manually in **BankCORE**.

This is written so it can be:

* Used as internal training material
* Embedded in a help drawer
* Converted into a compliance SOP

---

# Advisory Creation Decision Tree

(Manual Entry — Party / Account)

---

# STEP 1 — Should an Advisory Be Created?

### Q1: Does this information affect how staff interact with the customer or account?

* **No** → Do not create advisory.
* **Yes** → Continue.

---

### Q2: Is this information already enforced elsewhere in the system?

Examples:

* Account freeze flag

* OFAC match

* Deceased flag

* Legal hold

* **Yes (system control exists)** → Only create advisory if additional human instruction is required.

* **No** → Continue.

---

### Q3: Does failing to communicate this information create risk?

| Risk Type    | Examples                |
| ------------ | ----------------------- |
| Operational  | Misapplied funds        |
| Fraud        | Suspicious activity     |
| Regulatory   | CTR, OFAC, CIP          |
| Legal        | Court order, bankruptcy |
| Relationship | VIP handling            |

* **No risk** → Use internal notes outside Advisory system (if applicable).
* **Yes** → Create Advisory.

---

# STEP 2 — Determine Severity

Use this branching logic:

---

## A. Is the action legally or regulatorily prohibited?

Examples:

* Court-ordered freeze
* OFAC positive
* Confirmed fraud lock
* Bankruptcy debit restriction

→ **Severity 4 — Restriction**

---

## B. Must the teller consciously review and confirm before proceeding?

Examples:

* Verbal password required
* Identity discrepancy noted
* Pending fraud review
* Disputed transaction

→ **Severity 3 — Requires Acknowledgment**

---

## C. Does this increase risk but not require workflow interruption?

Examples:

* Recent returned checks
* Pattern of large cash withdrawals
* Monitoring flag

→ **Severity 2 — Alert**

---

## D. Is this helpful but non-risk information?

Examples:

* High-value client
* Prefers specific branch
* Recent account changes

→ **Severity 1 — Notice**

---

## E. Is this documentation only?

Examples:

* Internal summary
* Relationship history

→ **Severity 0 — Record**

---

# STEP 3 — Should It Be Pinned?

### Pin if:

* It affects near-term activity
* It relates to fraud/compliance
* It requires behavioral adjustment
* It is temporary but urgent
* It is critical context for next 30–60 days

### Do NOT pin if:

* Long-term static restriction (Restriction severity already elevates it)
* Informational history
* Low-risk preference notes

**Rule of Thumb:**
Pin for urgency, not importance.

---

# STEP 4 — Effective Dates

### Q1: Is this permanent?

Examples:

* Deceased customer
* Bankruptcy order
* Legal freeze

→ Leave end date blank.

---

### Q2: Is this temporary?

Examples:

* Fraud investigation pending
* Travel notice
* Address verification in progress
* Enhanced monitoring

→ Set end date.

Recommended durations:

| Scenario              | Suggested Duration  |
| --------------------- | ------------------- |
| Travel notice         | Exact travel window |
| Fraud review          | 30–90 days          |
| Documentation pending | 30 days             |
| Monitoring            | 60 days             |

---

### Q3: Is the start date in the future?

Examples:

* Scheduled legal hold
* Pre-notified account action

→ Set future start date.

---

# STEP 5 — Workspace Visibility

### Teller Workspace?

Use if it affects transactions or cash handling.

### CSR Workspace?

Use if it affects:

* Account maintenance
* CIF updates
* Customer communications

### Both?

Most fraud/compliance advisories should be both.

---

# STEP 6 — Category Assignment

Categories help filtering and audit.

Recommended base categories:

| Category     | Usage                            |
| ------------ | -------------------------------- |
| Fraud        | Suspicious or confirmed fraud    |
| Compliance   | Regulatory requirements          |
| Legal        | Court orders, legal restrictions |
| Operational  | Workflow instructions            |
| Relationship | Customer service notes           |
| Monitoring   | Risk watch flags                 |

---

# STEP 7 — Sanity Check Before Saving

Operator checklist:

* Is severity justified?
* Is wording factual (not emotional)?
* Does the advisory state objective facts?
* Are effective dates correct?
* Does it duplicate an existing advisory?
* Would a regulator understand why this exists?

---

# Visual Decision Flow (Text Diagram)

```
Does this affect staff behavior?
        |
        v
Is there risk if ignored?
        |
        v
Is action prohibited by law/compliance?
        |---- Yes → Restriction
        |
        No
        |
Must staff explicitly confirm before proceeding?
        |---- Yes → Requires Acknowledgment
        |
        No
        |
Does it elevate financial/fraud risk?
        |---- Yes → Alert
        |
        No
        |
Is it helpful operational context?
        |---- Yes → Notice
        |
        No
        |
Documentation only → Record
```

---

# Examples by Scenario

### Scenario: Verbal password required

→ Requires Acknowledgment
→ Pin = Yes
→ No end date

---

### Scenario: Customer traveling internationally for 2 weeks

→ Alert
→ Pin = Yes
→ Effective end = travel end date

---

### Scenario: Account frozen due to fraud

→ Restriction
→ Pin = Optional (Severity already elevates)
→ No end date

---

### Scenario: VIP customer

→ Notice
→ Pin = No
→ No end date

---

# Governance Guidance

* Restriction and Requires Acknowledgment advisories should be created by supervisor/compliance roles.
* Severity downgrade requires documented reason.
* Avoid vague language like:

  * “Be careful”
  * “Something seems off”
* Use objective statements:

  * “Customer disputes $2,500 ACH dated 01/15/2026.”
  * “Court order received 02/10/2026 prohibiting debit transactions.”

---

# Final Behavioral Philosophy

The Advisory system exists to:

* Prevent financial loss
* Prevent regulatory violations
* Document conscious review
* Communicate risk clearly
* Avoid unnecessary workflow friction

