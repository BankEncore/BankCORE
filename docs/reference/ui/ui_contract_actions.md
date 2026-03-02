# UI Contract — Actions (Buttons, Links, Placement)

**Audience:** BankCORE workstation UI (Teller/Ops/CSR shells)  
**Purpose:** Standardize **where actions live**, **what component to use**, and **how actions are labeled \+ styled** across pages, workflows, tables, and modals.

---

## 1\) Action Taxonomy

### 1.1 Levels (what the action applies to)

- **Global / Workspace:** affects shell/workstation context (switch branch/workstation, sign out)  
- **Page-level:** affects current record/list screen (New, Export, Back, Close)  
- **Transaction-level:** affects in-progress workflow state (Submit, Post, Void, Request Approval)  
- **Section-level:** affects a page panel/section (Add Item, Filter, Expand)  
- **Line-level (Row-level):** affects a single row (Edit, Remove, Reverse, View)  
- **Inline-field:** affects a single input (Clear, Copy, Lookup)

### 1.2 Risk classes (controls emphasis \+ friction)

- **Primary Commit:** creates/updates financial state; posts/commits  
- **Secondary Commit:** advances workflow without final posting (Save Draft, Continue)  
- **Navigation:** Back/Close/Cancel  
- **Mutation (Non-financial):** edits non-posting data (memo, attachment)  
- **Danger (Destructive):** void/reverse/delete/abandon  
- **Assist / Utility:** view/print/copy/help  
- **Supervisor / Controlled:** requires approval or elevated permission

---

## 2\) Placement Standards

### 2.1 Page header actions (Record/List screens)

**Location:** top-right of page header.

**Rules**

- Max **2 visible** actions in header.  
- **Primary** action far-right.  
- **Back/Close** far-left (or consistent “secondary slot”).  
- Anything beyond 2 goes into an **Actions** overflow menu.

**Mapping**

- Primary: `New …`, `Start Transaction`, `Edit`, `Save`  
- Secondary: `Back`, `Close`, `Cancel`  
- Overflow: `Export`, `Print`, `Audit Trail`, `View History`

---

### 2.2 Transaction shell actions (Workflow screens)

**Location:** bottom-right **sticky action bar** (or fixed footer inside transaction panel).

**Rules**

- Exactly **one** primary commit action (e.g., `Post`, `Submit`, `Complete`).  
- `Cancel` is left of primary (or bottom-left) and never dominates visually.  
- High-risk actions (`Void`, `Reverse`) are **not adjacent** to primary commit; use overflow or separated grouping.

**Required pattern**

- Left: validation/status summary (“Ready”, “Needs approval”, “Out of balance”)  
- Right: `Cancel` \+ `Primary Commit` (+ overflow)

---

### 2.3 Section-level actions (within panels/cards)

**Location:** top-right of section header row.

**Rules**

- Must be local to the section (not page/transaction commits).  
- Smaller/lower emphasis than page-level actions.  
- Examples: `Add Check`, `Add Fee`, `Add Note`, `Filter`, `Expand`

---

### 2.4 Line-level actions (tables/lists)

**Location:** rightmost column, consistent width, aligned to row baseline.

**Rules**

- Prefer **compact icon actions** with tooltips.  
- Max **2 inline** actions; additional actions go into row overflow.  
- Destructive actions: overflow by default, always confirm.

**Default**

- Inline: `View` and/or `Edit`  
- Overflow: `Remove`, `Reverse`, `Adjust`, `History`

---

### 2.5 Inline-field actions (inside form controls)

**Location:** trailing area within the control or adjacent micro button.

**Rules**

- Must not look like a commit action.  
- Should be reversible/non-destructive.  
- Examples: `Lookup`, `Clear`, `Copy`, `Scan`

---

## 3\) Component Standards (What to Use)

### 3.1 Button vs Link

Use **buttons** for:

- state mutation (create/update/delete)  
- open modal/overlay  
- submit/commit workflow steps

Use **links** for:

- navigation between screens  
- view-only transitions where no state changes occur

### 3.2 Primary / Secondary / Tertiary

- **Primary:** one per context (page or transaction). Commits or advances.  
- **Secondary:** supportive actions (`Back`, `Save Draft`, `Add Item`).  
- **Tertiary:** low emphasis utilities (`Print`, `View receipt`).  
- **Icon button:** line-level and micro utilities only.

### 3.3 Danger semantics

Use danger styling only for:

- `Void`, `Reverse`, `Delete`, `Abandon`, `Remove`

Never use danger styling for:

- `Cancel`, `Back`, `Close`

### 3.4 Disabled vs Hidden

- **Disabled:** action is visible but prerequisites not met (include nearby explanation).  
- **Hidden:** user lacks permission OR action is not applicable in this context.

---

## 4\) Labeling Rules

### 4.1 Verbs \+ outcomes

Prefer: `Post Deposit`, `Submit for Approval`, `Reverse Transaction`  
Avoid: `OK`, `Go`, `Yes`

### 4.2 Include object where ambiguity exists

- Page: `New Account`, `New Party`  
- Section: `Add Check`  
- Line: `Remove Fee`, `Edit Check`

### 4.3 Approval language

- Teller triggers approval: `Request Approval`  
- Supervisor decision: `Approve` / `Decline`  
- Teller resumes after approval: `Continue`

---

## 5\) Confirmation & Safety Friction

### 5.1 Confirmation required

Confirm modal (or equivalent) required for:

- destructive actions (delete/remove/abandon)  
- void/reversal actions  
- posting/committing irreversible batches  
- leaving an in-progress transaction with entered amounts

### 5.2 Allowed two-step patterns

- Button → confirm modal → commit  
- Button → supervisor prompt → approve/deny → continue/commit  
- Overflow menu → confirm modal → commit

### 5.3 Disallowed

- destructive click with no confirm  
- placing `Void` immediately adjacent to `Post`

---

## 6\) Keyboard, Focus, and Accessibility

- Primary action must be reachable predictably by tab order.  
- `Enter` submits only within an explicit submit context (never triggers destructive actions).  
- `Escape` closes modals/overlays (never posts).  
- Icon buttons must have:  
  - tooltip  
  - accessible label (aria-label)  
  - adequate target size for workstation use

---

## 7\) Default Layout Patterns

### 7.1 Record/list header

- Left: title \+ context  
- Right: `Back` (secondary) | `Primary` (Edit/New/Save) | `Actions` (overflow)

### 7.2 Transaction footer bar

- Left: validation/status summary  
- Right: `Cancel` (secondary) | `Post/Submit` (primary) | overflow (Void/Reverse/etc.)

### 7.3 Tables

- Rightmost column: compact `View/Edit`  
- Overflow: all other actions, especially destructive

---

## 8\) Styling Mapping (DaisyUI / Tailwind)

**Recommended mapping (subject to theme tokens):**

- Primary commit: `btn btn-primary`  
- Secondary: `btn` or `btn btn-outline`  
- Tertiary/utility: `btn btn-ghost`  
- Danger: `btn btn-error` (confirm required)  
- Row icon actions: `btn btn-ghost btn-xs` (or `btn-sm` if needed)  
- Overflow: `dropdown` \+ `btn btn-ghost` trigger

---

## 9\) Anti-Patterns (Not Allowed)

- More than one primary action visible in the same context.  
- Destructive actions next to primary commit without separation \+ confirm.  
- Row actions scattered across multiple columns.  
- Link-styled controls used for posting/commit actions.  
- `Cancel` styled as danger.

---

## 10\) Control & Audit Expectations (BankCORE)

- Financial commits must be **intentional**: explicit labels \+ confirmation where required.  
- Approval-required actions must clearly indicate approval state and next step.  
- Mutations must be permission-gated; missing permissions must not expose non-functional controls.  
- Commits should produce auditable events (who/what/when/why) per posting and approval flows.
