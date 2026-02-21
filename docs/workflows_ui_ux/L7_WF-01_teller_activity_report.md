
# L7-WF-01 — OPS-010 Teller Activity Report

**Status:** DROP-IN SAFE (Phase 1 reporting contract)

## 1) Purpose

Provide summary visibility into teller financial activity by:

* Teller
* Branch
* Date range
* Session

Used for:

* Daily balancing oversight
* Exception spotting
* Volume review

---

## 2) Route

* `GET /ops/reports/teller_activity`

---

## 3) Filters (tabbable)

1. Branch (required unless user scoped to one branch)
2. Date range (default: today)
3. Teller (optional)
4. Workstation (optional)
5. Session ID (optional)
6. Run Report

---

## 4) Report Output (Summary Layer)

### 4.1 Teller Summary Table

Columns:

* Teller
* Sessions Opened
* Total Cash In
* Total Cash Out
* Drafts Issued
* Checks Cashed
* Fees Collected
* Transfers Count
* Reversals Count
* Net Cash Impact

### 4.2 Drill-down

Each teller row clickable → OPS-030 Session Detail

---

## 5) Acceptance checklist

* [ ] Date filter works reliably
* [ ] Totals reconcile with posting data
* [ ] Drill-down available
* [ ] No transaction editing in Ops shell
