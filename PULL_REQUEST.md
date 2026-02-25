# Check Hold Date & Funds Availability

## Summary

- **What does this change do?** Adds check hold/on-transit handling, editable hold reason and hold-until date, a funds availability panel on deposit workflows, and deposit receipt availability tables. Also improves receipt styling (font size, margins) and includes non-CIF account numbers on receipts.
- **Why is it needed?** Tellers need to set and display check holds and transit status. Customers need clear visibility into when deposited funds become available. Receipts should show accurate account references and be easier to read when printed.

## Scope

- [x] Backend (Rails models/controllers/services)
- [x] Frontend (Hotwire/Stimulus/views)
- [ ] Database (migrations/schema)
- [ ] Docs
- [ ] CI/DevEx

## Checklist

- [x] I ran focused tests for this change
- [x] I ran `bin/rubocop` on changed Ruby files
- [ ] I ran security checks relevant to this change (`brakeman`, `bundler-audit`, `importmap audit`)
- [ ] I updated docs/status where applicable
- [x] I did not include unrelated refactors

## Test Evidence

Commands run:

```bash
bundle exec rails test test/helpers/teller/receipts_helper_test.rb test/services/posting/recipe_builder_test.rb test/controllers/teller/postings_controller_test.rb
bin/rubocop app/helpers/teller/receipts_helper.rb app/services/posting/recipe_builder.rb
```

Results:

```text
# Tests
14 runs, 42 assertions, 0 failures, 0 errors, 0 skips

# Rubocop (branch Ruby files)
No offenses detected in changed Ruby files
```

## Risk & Rollback

- **Risk level:** Low
- **Potential impact:** New UI elements (hold modal, funds availability panel) and receipt changes. Existing posting flows remain compatible; new fields are additive.
- **Rollback plan:** Revert the branch. No migrations; all changes are in application code.

## Related

- Closes #51109
- Related docs/specs: (add links if applicable)

---

## Implementation Details

### Features

| Feature | Description |
|---------|-------------|
| **Check Transit/On Us + Hold** | `check_type` (transit/on_us), editable `hold_reason` and `hold_until`, Type/Hold columns in posting workspace, hold modal with fixed reasons, default 5 business days |
| **Deposit receipt availability** | `add_business_days`, `deposit_availability_rows`: cash immediate, non-held checks first $250 next biz day, remainder 2 biz days, held checks by `hold_until` |
| **Receipt print styling** | `text-xs` for body, `@page { margin: 0 }`, no print border |
| **Account numbers on receipts** | `customer_account_reference?`, `account_summaries_by_account` groups by `account_reference`, includes non-existing accounts |
| **Funds availability panel** | Dynamic panel below Drawer Totals on deposit screens |
| **Check amount alignment** | `mono` class on amount column in receipt check details |

### Files changed

| File | Change |
|------|--------|
| `app/helpers/teller/receipts_helper.rb` | `HOLD_REASONS`, `customer_account_reference?`, `account_summaries_by_account`, `add_business_days`, `deposit_availability_rows`, `check_hold_indicator` |
| `app/services/posting/recipe_builder.rb` | Check type, hold reason, hold until |
| `app/controllers/concerns/teller_posting_execution.rb` | Pass hold fields to recipe |
| `app/controllers/teller/transactions_controller.rb` | Hold-related params |
| `app/javascript/controllers/posting_form_controller.js` | Funds availability panel targets, `renderFundsAvailability` |
| `app/javascript/controllers/hold_modal_controller.js` | Hold modal behavior |
| `app/javascript/services/posting_payload.js` | Hold fields in payload |
| `app/views/teller/shared/_check_hold_modal.html.erb` | Hold modal partial |
| `app/views/teller/shared/_funds_availability_panel.html.erb` | Availability panel partial |
| `app/views/teller/dashboard/_posting_workspace.html.erb` | Hold modal, funds panel, Type/Hold columns |
| `app/views/teller/receipts/_deposit.html.erb` | Availability table |
| `app/views/teller/receipts/_receipt_account_info.html.erb` | Handles nil account, non-CIF reference |
| `app/views/teller/receipts/_receipt_check_details.html.erb` | `mono` class on amount |
| `app/views/teller/receipts/*.erb` | Account info partial usage |
| `app/assets/tailwind/application.css` | Print styles |
| `test/*` | Helper, recipe, controller tests |
