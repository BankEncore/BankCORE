```mermaid
flowchart TD
  %% Entry / Auth
  A[Login] --> B{Authenticated?}
  B -- No --> A
  B -- Yes --> C[App Shell Router]

  %% Shell router
  C -->|/teller| T0[Teller Router]
  C -->|/ops| O0[Ops Router]
  C -->|/ (root)| H[Home / Role Landing]

  %% Teller Router gates
  T0 --> T1{Workstation Context Set?}
  T1 -- No --> WS005[WS-005 Context Gate<br/>Select Branch + Workstation]
  WS005 --> T0

  T1 -- Yes --> T2{Workstation Locked?}
  T2 -- Yes --> WS015[WS-015 Locked Screen<br/>Unlock Required]
  WS015 -->|Unlock success| T0
  WS015 -->|Logout| A

  T2 -- No --> T3{Open Teller Session?}
  T3 -- No --> WS100[WS-100 Session Status<br/>No open session]
  WS100 --> WS110[WS-110 Open Session]
  WS110 -->|Posted| WS110R[Receipt: Session Open]
  WS110R --> WS010

  T3 -- Yes --> WS010[WS-010 Teller Dashboard]

  %% Teller dashboard actions
  WS010 --> WS030[WS-030 Recent Activity]
  WS010 --> WS120[WS-120 Close Session]
  WS010 --> TXNAV{Start Transaction}

  TXNAV --> WS200[WS-200 Deposit]
  TXNAV --> WS210[WS-210 Withdrawal]
  TXNAV --> WS220[WS-220 Transfer]
  TXNAV --> WS230[WS-230 Check Cashing]
  TXNAV --> WS240[WS-240 Bank Draft]
  TXNAV --> WS250[WS-250 Bill Payment]
  TXNAV --> WS260[WS-260 Misc Receipt]
  TXNAV --> WS300[WS-300 Vault Transfer]

  %% Common transaction lifecycle
  subgraph LIFECYCLE [Global Posting Lifecycle]
    E[Editing] --> V[Validating]
    V -->|Blocking errors| E
    V -->|Approval required| AR[Approval Required]
    AR -->|Open Approval Modal| AM[Approval Modal]
    AM -->|Denied/Cancelled| AR
    AM -->|Approved| P[Posting]
    V -->|No approval needed| P
    P -->|Success| R[Receipt Block]
    P -->|System error| SE[System Error State]
    R -->|New Transaction| E
  end

  %% Link transactions to the entry node of the lifecycle
  WS200 -. uses .-> E
  WS210 -. uses .-> E
  WS220 -. uses .-> E
  WS230 -. uses .-> E
  WS240 -. -.-> E
  WS250 -. -.-> E
  WS260 -. -.-> E
  WS300 -. -.-> E
  WS120 -. uses .-> E

  %% Receipts / viewer / reversal
  WS030 --> WS031[WS-031 Receipt Viewer]
  WS031 -->|Print| WS031
  WS031 -->|Back| WS030

  WS031 -->|Reverse| WS040[WS-040 Reversal Review]
  WS040 -->|Approval Req| AM
  AM -->|Approved| WS041[WS-041 Reversal Receipt]
  WS041 --> WS030

  %% Session close outcome
  WS120 -->|Posted| WS120R[Receipt: Session Close]
  WS120R -->|Return| WS010

  %% Teller Lock / Logout
  WS010 -->|Lock| WS015
  WS010 -->|Logout| A
  WS030 -->|Lock| WS015
  WS030 -->|Logout| A

  %% CIF placeholder
  WS200 -->|New Tab| CIF[(CIF Shell)]
  WS210 -->|New Tab| CIF
  WS220 -->|New Tab| CIF
  WS031 -->|New Tab| CIF

  %% Ops shell
  O0 -->|Auth| OPSHOME[Ops Dashboard]
  OPSHOME --> OPS010[OPS-010 Activity Report]
  OPSHOME --> OPS020[OPS-020 Session Search]
  OPS010 --> OPS030[OPS-030 Session Detail]
  OPS020 --> OPS030
  OPS030 --> OPSR[Receipt View]
  OPSR --> OPS030

  OPSHOME -->|Logout| A
  WS010 -->|Open Ops| OPSHOME
  ```