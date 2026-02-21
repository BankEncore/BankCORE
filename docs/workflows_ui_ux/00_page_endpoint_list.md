# Workstation / context

* WS-000 Workstation Landing [/teller/*]
* WS-005 Workstation Context Gate
* WS-010 Teller Dashboard
* WS-015 Workstation Locked / Suspend

## Session lifecycle

* WS-100 Session Status [/teller/session/*]
* WS-110 Open Session [/teller/session/open]
* WS-120 Close Session (Balancing) [/teller/session/*/close]

## Transaction entry modes

* WS-200 Deposit [/teller/transactions/deposit/]
* WS-210 Withdrawal
* WS-220 Transfer
* WS-230 Check Cashing
* WS-240 Bank Draft
* WS-250 Bill Payment
* WS-260 Misc Receipt
* WS-300 Vault Transfer

## Teller lookup / receipts

* WS-030 Recent Activity (My Transactions)** *(recommended)*
* WS-031 Receipt Viewer (Read-only)** *(recommended)*

## Corrections

* WS-040 Reverse Transaction (Request)** *(strongly recommended)*
* WS-041 Reversal Receipt (Read-only)** *(recommended)*

---

# 4) What I would *not* add yet (unless you need it immediately)

* Cash adjustments outside reversal framework
* Denomination breakdown screens (can be v1.1+)
* CTR/WCTR data capture screens (unless your Phase 1 explicitly includes it)
* Holds management screens beyond what’s embedded in deposit/check flows
