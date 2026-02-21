
# L6-WF-04 — Receipt Viewer (WS-031)

**Status:** **Fits but needs working changes**
**Current Implementation Mapping:** Read-only receipt viewing exists at `GET /teller/receipts/:request_id`; reversal-linked viewer actions in this doc are not implemented.
**Purpose:** Read-only view of a posted receipt, with print and (if eligible) reversal.

## 1) Content

* Render the same receipt block as post-success
* Show:

  * Print
  * Back to Activity
  * Reverse (if eligible) → WS-040

## 2) Rules

* Receipt is server-authoritative and immutable
* If already reversed:

  * show reversal linkage and disable reverse button

## 3) Acceptance checklist

* [ ] Receipt matches printed receipt layout
* [ ] Print works identically to post-success
* [ ] Reversal launch is controlled by eligibility
