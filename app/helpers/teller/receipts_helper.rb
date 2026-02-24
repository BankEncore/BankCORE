# frozen_string_literal: true

module Teller
  module ReceiptsHelper
    def masked_account_number(account_number)
      return "—" if account_number.blank?
      str = account_number.to_s.strip
      return "xxxx" if str.length < 4
      "xxxx" + str[-4, 4]
    end

    def customer_account_transactions(posting_batch)
      posting_batch.account_transactions
        .select { |at| at.account_id.present? }
        .group_by(&:account_id)
        .flat_map do |_account_id, transactions|
          transactions
        end
        .uniq
        .sort_by { |at| [ at.account_id, at.direction ] }
    end

    def account_summary_for_receipt(account_transaction)
      account = account_transaction.account
      return nil unless account

      net_cents = account_transaction.direction == "credit" ? account_transaction.amount_cents : -account_transaction.amount_cents
      current_balance = account.balance_cents
      previous_balance = current_balance - net_cents

      {
        account: account,
        previous_balance_cents: previous_balance,
        credit_or_debit_cents: account_transaction.direction == "credit" ? account_transaction.amount_cents : -account_transaction.amount_cents,
        pending_balance_cents: current_balance
      }
    end

    def account_summaries_by_account(posting_batch)
      by_account = posting_batch.account_transactions
        .select { |at| at.account_id.present? }
        .group_by(&:account_id)

      by_account.map do |account_id, transactions|
        account = Account.find_by(id: account_id)
        next nil unless account

        total_credit = transactions.select { |t| t.direction == "credit" }.sum(&:amount_cents)
        total_debit = transactions.select { |t| t.direction == "debit" }.sum(&:amount_cents)
        net_cents = total_credit - total_debit
        current_balance = account.balance_cents
        previous_balance = current_balance - net_cents

        {
          account: account,
          previous_balance_cents: previous_balance,
          credit_cents: total_credit,
          debit_cents: total_debit,
          pending_balance_cents: current_balance
        }
      end.compact
    end

    def check_items_from_metadata(posting_batch)
      meta = posting_batch.metadata
      return [] unless meta.is_a?(Hash)

      meta = meta.with_indifferent_access
      items = meta["check_items"] || meta.dig("check_cashing", "check_items")
      Array(items).map { |i| i.is_a?(Hash) ? i.with_indifferent_access : {} }
    end

    def receipt_money(cents)
      number_to_currency((cents || 0) / 100.0)
    end

    def check_hold_indicator(item)
      hold_reason = (item["hold_reason"] || item[:hold_reason]).to_s
      return "T*" if hold_reason.blank? || hold_reason == "on_us"
      return "T" if hold_reason.include?("teller") || hold_reason == "teller"
      "O"
    end

    def cash_location_display_name(reference, branch)
      return "—" if reference.blank? || branch.blank?
      code = reference.to_s.sub(/\Acash:/i, "").strip
      return reference if code.blank?
      loc = CashLocation.find_by(branch_id: branch.id, code: code)
      return "#{code} (unresolved)" if loc.blank?
      "#{loc.location_type.titleize} #{loc.name}"
    end
  end
end
