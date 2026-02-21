# BankCORE

## System Charter – Iteration 1

### Teller Operations & Cash Control Platform

> **Note:** This charter describes intent and directional scope.
> The authoritative Phase 1 scope and acceptance criteria are in: `docs/10_phase1_spec.md`.

---

# 1\. Purpose

BankCORE Iteration 1 establishes a controlled, balanced teller transaction and cash management platform.

The system is designed to:

* Record and process teller-originated financial events  
* Maintain drawer and vault accountability  
* Generate balanced account postings  
* Support supervisory approval workflows  
* Provide auditable transaction records  
* Interface with, but not fully implement, CIF, account servicing, or general ledger systems

This iteration focuses exclusively on operational teller management while establishing foundational structures for future core banking expansion.

---

# 2\. System Scope (In Scope – v1)

## 2.1 Teller Operations

The system shall support the following teller transaction types:

* Deposits  
* Withdrawals  
* Transfers  
* Check cashing  
* Official check issuance (bank drafts)  
* Bill payments  
* Miscellaneous receipts  
* Vault transfers

Each transaction:

* Is a discrete operational event  
* Occurs within an open teller session  
* Produces balanced posting legs  
* May produce cash movements  
* May generate instrument records  
* May require supervisory approval  
* Must be fully auditable

---

## 2.2 Teller Session & Drawer Control

The system shall:

* Open and close teller sessions  
* Maintain beginning and ending drawer balances  
* Track real-time cash position  
* Record vault-to-drawer and drawer-to-vault transfers  
* Support over/short reporting  
* Support supervisory overrides

---

## 2.3 Posting Engine (Operational Ledger Layer)

The system shall:

* Generate balanced debit and credit posting legs  
* Validate that all transactions balance prior to commit  
* Persist posting records separate from operational transaction records  
* Update account balances through controlled posting mechanisms  
* Maintain immutable audit history

Teller operations do not directly modify balances; they submit posting legs to the posting engine.

---

## 2.4 Minimal Account Domain (Ledger Stub)

The system shall include a minimal account ledger sufficient to:

* Store deposit and credit accounts  
* Record account postings  
* Maintain running balances  
* Support balance validation during teller processing  
* Enforce basic restrictions (e.g., closed, restricted, frozen)

This domain does not include:

* Interest accrual  
* Product lifecycle management  
* Full deposit operations platform features

---

## 2.5 Minimal Identity Domain (CIF Stub)

The system shall include:

* Parties (individuals and organizations)  
* Account-party relationships  
* Alerts tied to parties or accounts  
* Basic identification tracking

This iteration does not include:

* Full onboarding workflows  
* Risk scoring engines  
* Complex relationship graphs  
* Enterprise-wide customer lifecycle management

---

## 2.6 Instrument Control

The system shall track:

* Official checks issued  
* Instrument numbers  
* Outstanding liabilities  
* Status (issued, voided, cleared)

---

## 2.7 GL Integration Layer (Stub)

The system shall:

* Support GL mapping templates  
* Produce derived GL entries from posting legs  
* Maintain traceability between teller transactions and GL impact

Iteration 1 does not implement a full general ledger system.

---

# 3\. System Boundaries (Out of Scope – v1)

The following domains are intentionally excluded from Iteration 1:

* Interest accrual engines  
* Automated clearing house (ACH) processing  
* Wire transfer processing  
* Loan amortization logic  
* Fee scheduling engines (beyond basic posting)  
* Enterprise reporting platform  
* Enterprise risk systems  
* Regulatory reporting automation (CTR, SAR, etc.)  
* Full general ledger with financial statement generation

These may be integrated in future iterations.

---

# 4\. Architectural Principles

## 4.1 Separation of Concerns

The system separates:

| Domain | Responsibility |
| :---- | :---- |
| Teller | Operational transaction event |
| Posting Engine | Financial debits/credits |
| Account Domain | Balance maintenance |
| Cash Control | Physical currency accountability |
| GL Layer | Financial reporting derivation |

---

## 4.2 Double-Entry Integrity

All teller transactions must:

* Produce balanced debit and credit posting legs  
* Be validated prior to commit  
* Be immutable after finalization  
* Be fully traceable

---

## 4.3 Auditability

The system shall:

* Record user ID and session for all activity  
* Record timestamps for all actions  
* Record supervisor approval events  
* Maintain effective-dated records where applicable  
* Prevent destructive edits to financial records

---

## 4.4 Supervisory Controls

The system shall support:

* Threshold-based supervisor approval  
* Alert-triggered escalation  
* After-the-fact approval capture (where permitted)  
* Override logging with reason codes

---

## 4.5 Extensibility

The architecture must:

* Support expansion into full core banking  
* Allow replacement of stub domains with full modules  
* Avoid embedding business logic that belongs in future domains  
* Preserve backward compatibility of posting structures

---

# 5\. Core Data Domains (v1)

1. Identity (Parties)  
2. Accounts  
3. Account Parties  
4. Account Postings  
5. Teller Transactions  
6. Posting Legs  
7. Cash Locations (Drawer, Vault)  
8. Instrument Records  
9. Alerts  
10. Approval Events  
11. GL Templates (Stub)

---

# 6\. Control Objectives

Iteration 1 is designed to achieve:

* Cash accountability by drawer and vault  
* Transaction-level audit traceability  
* Balanced financial posting enforcement  
* Supervisor override governance  
* Foundational ledger integrity

---

# 7\. Future Expansion Path

Subsequent iterations may include:

* Full CIF lifecycle management  
* Full product engine  
* Interest and accrual systems  
* Fee engine  
* Regulatory reporting automation  
* Enterprise GL  
* Multi-channel integration (ATM, online, mobile)

---

# 8\. Governance Statement

BankCORE Iteration 1 establishes the operational and financial integrity foundation upon which future core banking modules will be built. The system prioritizes:

* Double-entry correctness  
* Cash accountability  
* Audit traceability  
* Modular expansion capability

No architectural decisions in Iteration 1 shall preclude future migration into a full core banking platform.
