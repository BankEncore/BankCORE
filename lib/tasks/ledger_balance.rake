# frozen_string_literal: true

namespace :ledger do
  desc "Rebuild ledger_balance_cents from account_transactions; repairs diffs by default (pass REPAIR=false to report only)"
  task rebuild_balances: :environment do
    repair = ENV.fetch("REPAIR", "true") != "false"
    LedgerBalanceTasks.rebuild(repair: repair)
  end

  desc "Validate ledger_balance_cents against account_transactions; reports diffs only (no repair)"
  task validate_balances: :environment do
    LedgerBalanceTasks.validate
  end
end
