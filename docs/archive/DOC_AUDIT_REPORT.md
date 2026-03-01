# BankCORE Documentation Audit Report

> **Purpose:** Sort through accumulated docs — what's valid, what matches the project, where we veered off.

**Audit date:** 2026-03-01  
**Scope:** `docs/` folder (all markdown, notes, workflows, mockups)

---

## 1. TL;DR — Quick Reference

| Status | Count | Action |
|--------|-------|--------|
| **Valid & authoritative** | 5 | Keep; treat as source of truth |
| **Valid but stale** | 8+ | Update to match implementation |
| **Conceptual / directional** | 12 | Keep for context; not implementation spec |
| **Superseded / redundant** | 6 | Archive or delete |
| **Notes / working drafts** | ~15 | Keep in notes; don't treat as spec |

---

## 2. Valid & Authoritative (Source of Truth)

These are current, match implementation, and should remain primary references.

| Doc | Why it's valid |
|-----|----------------|
| **`10_phase1_spec.md`** | Explicitly tagged as authoritative Phase 1 scope. Acceptance criteria align with implementation. |
| **`00_system_charter_concept.md`** | Charter/intent document. Correctly points to Phase 1 spec as scope authority. |
| **`03_teller_focused_architecture_concept.md`** | Domain boundaries match `app/` (Teller, Posting, Account, Cash). |
| **`reversals.md`** | Policy matches `ReversalService`, reversals controller, posting flow. |
| **`approvals.md`** | Matches `POST /teller/approvals`, approval token flow. |

**Note:** `PROJECT_OVERVIEW.md` (new) is valid; one correction: theme docs describe `bankcore-light`/`bankcore-dark` but app uses a simpler `bankcore` theme in `daisyui.theme.js`. See §4 for details.

---

## 3. Valid But Stale (Update Needed)

Docs that describe the right structure but **lag behind implementation**. Code has moved on; docs say "Planned" when feature exists.

### 3.1 Docs say "Planned" — Code implements

| Feature | Docs that say Planned | Actual status |
|---------|------------------------|---------------|
| **Misc Receipt (WS-260)** | `00_page_endpoint_list.md`, `L5_WF-07`, `00_teller_ui_contract_v1`, `00_stimulus_event_matrix` | Implemented: routes, controller, WorkflowRegistry, RecipeBuilder, `misc_receipt_types` |
| **Reversals (WS-040/041)** | `00_page_endpoint_list.md`, `L5_WF-09` | Implemented: `ReversalsController`, `ReversalService`, schema, tests |
| **Ops sessions/ledger** | `00_page_endpoint_list.md`, `L7_WF-00` | Implemented: `GET /ops`, `GET /ops/ledger`, `GET /ops/sessions`, `GET /ops/sessions/:id` |

### 3.2 Docs missing content for implemented features

| Doc | Gap |
|-----|-----|
| **`02_teller_transaction_requirements.md`** | No `misc_receipt` section. WorkflowRegistry has it; doc does not. |
| **`10_phase1_status.md`** | Does not list misc receipt or reversals as done. Status otherwise accurate. |
| **`30_posting_refactor_spec.md`** | Bill Payment and Misc Receipt marked planned; Misc Receipt is implemented. |

### 3.3 UI/CSS docs vs implementation

| Doc | Mismatch |
|-----|----------|
| **`01_daisy_ui_theme.md`** | Describes full `bankcore-light` and `bankcore-dark`. App uses a single `bankcore` theme in `daisyui.theme.js`. Layout has no `data-theme` set. |
| **`02_ui_contract.md`** | Describes `shared/ui/_panel.html.erb` and `shared/ui/_kv_row.html.erb` partials. **They do not exist.** Views use the CSS classes directly. |

---

## 4. Conceptual / Directional (Useful, Not Implementation Spec)

These describe intent, architecture direction, or governance. They are **not** sources of truth for "what is built."

| Doc | Purpose | Note |
|-----|---------|------|
| `00_teller_module_mvp.md` | Conceptual MVP workflows | Explicitly says Phase 1 spec is authoritative. Misc receipt not in MVP list; code has it. |
| `01_phase1_master_plan_concept.md` | Phase 1 planning/governance | Superseded-by language; Phase 1 spec is canonical. |
| `02_phase1_roadmape_concept.md` | Sprint-structured roadmap | Assumes Devise, MariaDB; project uses different auth/DB. **Useful for sequencing ideas only.** |
| `11_ui_ux_standards_concept.md` | Teller UI/UX standards (concept) | Design governance; overlaps with `workflows_ui_ux/`. |
| `12_technical_ui_architecture_concept.md` | Technical UI architecture | Concept only. |
| `13_technical_ui_reference_concept.md` | Technical UI reference | Concept only. |
| `14_teller_ui_ux_standards_concept.md` | Teller UI/UX standards | Concept; overlaps with workflows_ui_ux. |
| `21_ux_with_mockups_concept.md` | UX mockups | Concept. |
| `22_teller_ui_dev_concept.md.md` | Teller UI dev | Concept. Duplicate `.md.md` in filename. |
| `workflows.md` | Phase 1 workflow inventory | Lists 25 workflows; some planned, some done. Misc receipt in list, implemented. |
| `250225_notes/*` | Posting architecture, controls, regulatory | Architectural notes; not implementation spec. |

**Recommendation:** Keep these for context. Add a header to each: *"Conceptual — implementation authority is `docs/10_phase1_spec.md`."* Consider consolidating 11/12/13/14/21/22 into a single `concepts/` folder.

---

## 5. Superseded / Redundant

Docs that duplicate or are superseded by other artifacts.

| Doc | Superseded by / Redundant with |
|-----|-------------------------------|
| **`00_project_summary_260223.md`** | Useful technical summary of Reference Summary + `tx:recalc` flow. **Keep** — it accurately describes implementation. Not redundant. |
| **`Check Cashing MVP Plan (Phase 1).prompt.md`** | One-off sprint prompt. Check cashing is done. **Archive or delete** — historical artifact. |
| **`plan-phase1AUiUxRealignment.prompt.prompt.md`** | Nested prompt file in mockups. **Archive or delete.** |
| **`header_revamp_instructions.md`** | Ad-hoc instructions. If revamp is done, **archive.** |
| **`22_teller_ui_dev_concept.md.md`** | Duplicate extension; likely typo. Rename or consolidate. |

---

## 6. Workflows UI/UX — Detailed Status

### Core contracts (workflows_ui_ux/)

| Doc | Status | Notes |
|-----|--------|-------|
| **README.md** | Valid | Layering table (L0–L7, X1–X3) is correct. Some linked docs are stale. |
| **00_teller_ui_contract_v1.md** | Stale | Misc Receipt, Bill Payment listed as Planned; Misc Receipt done. No F-key handling; command bar `tabindex` not as doc'd; no dirty-switch confirmation. |
| **00_page_endpoint_list.md** | **Stale** | WS-260 Misc Receipt, WS-040/041 Reversals marked Planned — both implemented. Ops sessions/ledger marked not implemented — they exist. |
| **00_stimulus_event_matrix_handoff.md** | Target/Stale | misc_receipt marked planned; done. Proposes `tx_shell`, `tx_keyboard`, `tx_validation` controllers; `posting_form_controller` owns most today. |
| **01_gap_analysis_2026-02-22.md** | Current | Accurately lists gaps. Some gaps now closed (misc_receipt, reversals, ops). |
| **02_teller_transaction_requirements.md** | **Partial** | **Source of truth for required/optional fields** — but missing `misc_receipt`. Deposit, Withdrawal, Transfer, Check Cashing, Draft, Vault Transfer documented. |

### L5 transaction workflows

| Doc | Status |
|-----|--------|
| L5_WF-01 Deposit | Implemented ✓ |
| L5_WF-02 Withdrawal | Implemented ✓ |
| L5_WF-03 Transfer | Implemented ✓ |
| L5_WF-04 Check Cashing | Implemented ✓ |
| L5_WF-05 Bank Draft | Implemented ✓ |
| L5_WF-06 Bill Payment | Planned (correct) |
| **L5_WF-07 Misc Receipt** | **Stale** — doc says Planned; implemented |
| L5_WF-08 Vault Transfer | Implemented ✓ |
| **L5_WF-09 Reversal** | **Stale** — doc says Planned; implemented |

### L0–L4, L6, L7

Most L0–L4 and L6 docs match implementation. L7 (Ops) docs say "not implemented" but ops routes and controllers exist.

---

## 7. Notes and Working Drafts

| Doc | Purpose |
|-----|---------|
| `notes/working_notes.md` | Working notes |
| `notes/2602261648_advisories_spec.md` | Advisory spec — implemented |
| `250225_notes/*` | Posting architecture, integrity risks, regulatory eval, etc. |
| `ui_csr_layout_notes.md` | CSR layout notes |
| `ui-record-pattern.md` | Record display pattern |
| `workflows_ui_ux/00_notes.md` | Workflow notes |
| `workflows_ui_ux/ui_mockups_and_notes.md` | UI mockups and notes |

**Recommendation:** Keep in `notes/` or `workflows_ui_ux/`. Treat as working context, not spec.

---

## 8. Seed Data and Mockups

| Item | Status |
|------|--------|
| `seed_data/*.csv` | Seed data; keep |
| `mockups/teller_mockup.html` | Uses `data-theme="light"` (generic), not bankcore. |
| `mockups/bankcore_mockup.html` | — |
| `mockups/receipt` | — |

---

## 9. Recommended Actions (Prioritized)

### High priority (doc/code sync)

1. **`00_page_endpoint_list.md`** — Mark Misc Receipt (WS-260), Reversals (WS-040/041), Ops sessions/ledger as **Implemented**.
2. **`02_teller_transaction_requirements.md`** — Add `misc_receipt` section and align with WorkflowRegistry.
3. **`10_phase1_status.md`** — Add misc receipt, reversals to done list.

### Medium priority (workflow docs)

4. **`L5_WF-07_misc_receipt.md`**, **`L5_WF-09_reversal_workflow.md`** — Update status to Implemented; align with code.
5. **`L7_WF-00_ops_backoffice_shell.md`** — Note ops sessions/ledger as implemented.
6. **`00_teller_ui_contract_v1.md`** — Update Misc Receipt to Implemented; keep Bill Payment Planned.
7. **`00_stimulus_event_matrix_handoff.md`** — Update misc_receipt to Implemented.

### Lower priority (cleanup)

8. **`01_daisy_ui_theme.md`** — Either document current `bankcore` single-theme setup, or implement `bankcore-light`/`bankcore-dark` as doc'd.
9. **`02_ui_contract.md`** — Either add `shared/ui/_panel.html.erb` and `_kv_row.html.erb`, or change doc to say "use classes directly (partials not implemented)."
10. **Concept docs (11, 12, 13, 14, 21, 22)** — Add "Conceptual" header; consider `docs/concepts/` subfolder.
11. **`22_teller_ui_dev_concept.md.md`** — Rename to `.md` (fix typo).
12. **`Check Cashing MVP Plan.prompt.md`**, **`plan-phase1AUiUxRealignment.prompt.prompt.md`** — Move to `docs/archive/` or delete.

---

## 10. Doc Hierarchy (Recommended)

```
docs/
├── PROJECT_OVERVIEW.md          # Onboarding
├── DOC_AUDIT_REPORT.md          # This file
├── 00_system_charter_concept.md
├── 03_teller_focused_architecture_concept.md
├── 10_phase1_spec.md            # AUTHORITATIVE scope
├── 10_phase1_status.md
├── 30_posting_refactor_spec.md
├── reversals.md
├── approvals.md
├── workflows.md
├── concepts/                    # Optional: consolidate 11,12,13,14,21,22
├── workflows_ui_ux/             # Keep structure; update stale docs
├── notes/                       # Working notes
├── seed_data/
├── mockups/
└── archive/                     # Optional: superseded prompts, one-offs
```

---

## 11. Summary: Where Did We Veer Off?

1. **Misc Receipt & Reversals** — Implemented but never folded into Phase 1 spec or status. Docs kept saying "Planned."
2. **Ops shell** — Sessions/ledger built; L7 docs never updated.
3. **UI theme** — Doc describes two themes; app uses one. Layout doesn't set `data-theme`.
4. **Shared UI partials** — Doc specifies them; they were never created. Classes used inline instead.
5. **Concept docs (11–14, 21–22)** — Accumulated over time; overlap with `workflows_ui_ux/`. No clear "this is concept only" boundary.
6. **Roadmap (`02_phase1_roadmape_concept.md`)** — Assumes Devise, MariaDB; project diverged. Sprint structure is illustrative only.

The **core architecture and posting model** have held. The drift is mainly in **workflow/endpoint status** and **UI/CSS docs** not matching implementation.
