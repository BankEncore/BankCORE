
# L6-WF-03 — Recent Activity (WS-030)

**Status:** **Partially aligned with current codebase**
**Current Implementation Mapping:** Recent history exists at `GET /teller/history`; route naming/contract differs from proposed WS-030.
**Implementation:** Partial. See [00_page_endpoint_list.md](00_page_endpoint_list.md) for route mapping.
**Purpose:** Let teller find prior posted transactions quickly for reprint and reversal initiation.

## 1) Default scope

* Default filter: **Current open teller_session**
* Optional toggles:

  * Today
  * This session (default)
  * Search by Ref #

## 2) List columns (table)

* Time
* Type
* Ref #
* Primary account masked (if applicable)
* Amount (signed if useful)
* Flags:

  * Approved
  * Reversed (and reversal ref)

Row actions:

* View Receipt (WS-031)
* Reverse (WS-040) *(only if eligible)*

## 3) Eligibility indicators

If not eligible to reverse:

* Reverse action disabled with tooltip text (display-only)

## 4) Acceptance checklist

* [ ] Fast list, minimal filters
* [ ] View Receipt always available
* [ ] Reverse only when eligible
* [ ] Defaults to current session scope
