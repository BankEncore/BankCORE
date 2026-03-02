# frozen_string_literal: true

class LedgerBalanceTasks
  def self.rebuild(repair: true)
    new.rebuild(repair: repair)
  end

  def self.validate
    new.validate
  end

  def rebuild(repair: true)
    diffs = compute_all_diffs
    report_diffs(diffs)

    if repair && diffs.any?
      repair_diffs(diffs)
    end
  end

  def validate
    diffs = compute_all_diffs
    report_diffs(diffs)
  end

  private

  def compute_all_diffs
    Account.find_each.each_with_object([]) do |account, diffs|
      computed = computed_balance_cents(account)
      cached = account.ledger_balance_cents
      next if computed == cached

      diffs << { account: account, computed: computed, cached: cached }
    end
  end

  def computed_balance_cents(account)
    credits = account.account_transactions.where(direction: "credit").sum(:amount_cents)
    debits = account.account_transactions.where(direction: "debit").sum(:amount_cents)
    credits - debits
  end

  def report_diffs(diffs)
    if diffs.empty?
      log "[LedgerBalance] No diffs found; all cached balances match computed."
      return
    end

    log "[LedgerBalance] Found #{diffs.size} account(s) with balance mismatch:"
    diffs.each do |d|
      log "  account=#{d[:account].account_number} computed=#{d[:computed]} cached=#{d[:cached]}"
    end
  end

  def repair_diffs(diffs)
    diffs.each do |d|
      account = d[:account]
      account.update!(
        ledger_balance_cents: d[:computed],
        ledger_balance_updated_at: Time.current
      )
      log "[LedgerBalance] Repaired account=#{account.account_number} -> #{d[:computed]}"
    end
  end

  def log(msg)
    Rails.logger.info msg
    puts msg if $stdout.tty?
  end
end
