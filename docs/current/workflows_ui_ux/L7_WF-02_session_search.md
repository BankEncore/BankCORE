# L7-WF-02 — OPS-020 Session Search

**Status:** Partially aligned with current codebase
**Current Implementation Mapping:** `GET /ops` shell landing exists; `GET /ops/sessions` route/controller is not implemented yet.

## 1) Purpose

Find teller sessions by:

* Date
* Teller
* Branch
* Status (Open/Closed)

---

## 2) Route

* `GET /ops/sessions`

---

## 3) Filters (tabbable)

* Branch
* Teller
* Date range
* Status (Open/Closed/All)

---

## 4) Result Table

Columns:

* Session ID
* Teller
* Branch
* Workstation
* Opened At
* Closed At
* Opening Cash
* Expected Closing Cash
* Counted Closing Cash
* Variance
* Status

Row action:

* View Session Detail (OPS-030)

---

## 5) Acceptance checklist

* [ ] Open sessions visible
* [ ] Closed sessions visible
* [ ] Variance clearly displayed
* [ ] No editing controls