# Related Records (Now Serving + Lookup Guidance)

## Summary

Streamlines teller workflow by allowing transactions to begin from either an **Account** or a **Party (CIF record)**. The system guides tellers toward likely related records while preserving independence between Served Party and Primary Account contexts.

## Features

### Entry Paths

- **Account-first flow:** Enter or select an account → related parties dropdown appears → optionally select served party
- **Party-first flow:** Select a party → related accounts dropdown appears → optionally select primary account

### Context Independence

- Served Party and Primary Account are independently editable
- No ownership or relationship validation at initiation (third-party transactions supported)
- Changing one context does not clear the other

### UI Layout

- **Row 1:** Party search/entry | Related parties select (when account chosen)
- **Row 2:** Primary Account search/entry | Related accounts select (when party chosen)
- Primary Account always on the second row; related dropdowns appear as optional select lists next to their corresponding fields
- Helper text ("Now serving...", "Add new non-customer") moved below the grid

### Audit & Metadata

- `initiating_lookup` (`account_first` | `party_first`) persisted in `PostingBatch.metadata`
- `AuditEvent` created on transaction post with `served_party`, `primary_account_reference`, `initiating_lookup`

## API Changes

- **NEW** `GET /teller/accounts/:id/related_parties` — returns parties linked to an account (Primary Owner, Owner)
- **Enhanced** `GET /teller/parties/:id/accounts` — adds `relationship_type` per account
- **Enhanced** Transaction search — accounts response includes `id` for related-parties lookup
- Account reference endpoint used for typed-account resolution (account-first by ID)

## Technical Changes

- New `_primary_account_search.html.erb` partial shared across deposit, withdrawal, transfer, draft, misc_receipt forms
- `_served_party_section.html.erb` accepts optional `right_column` for side-by-side layout
- Stimulus: `primary_account_search_controller` — related parties fetch, dropdown select, `resolveTypedAccount` on blur
- Stimulus: `party_search_controller` — fetches accounts on party select; `onRelatedAccountSelectChange` updates Primary Account and fetches related parties
- DB index: `account_owners(account_id, is_primary)` for query performance

## Testing

- Request tests for `related_parties` endpoint (auth, content, empty)
- Regression: deposit page renders Now Serving with Party, Primary Account, and both related selects
- Posting metadata test for `initiating_lookup`
- Committer test for `AuditEvent` with served party and initiating lookup
- Workflow validator: third-party (non-owner) transactions permitted
- System test locators updated to "Primary Account" (label change)

## Checklist

- [x] Account-first: related parties shown when account selected or typed
- [x] Party-first: related accounts shown when party selected
- [x] Selecting from related dropdowns populates Primary Account / Served Party correctly
- [x] Cancel clears both Party and Primary Account
- [x] Selecting related party does not clear Primary Account
- [x] Audit and metadata capture
