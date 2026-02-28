# frozen_string_literal: true

module Teller
  module ReceiptsHelper
    INTERNAL_ACCOUNT_PREFIXES = %w[cash: check: income: official_check:].freeze

    HOLD_REASONS = [
      [ "Large check amount", "large_item" ],
      [ "New account holder", "new_account" ],
      [ "Repeated overdrafts", "repeated_overdraft" ],
      [ "Third-party check", "third_party" ],
      [ "Foreign check", "foreign_item" ],
      [ "Possible duplicate", "duplicate_deposit" ],
      [ "Other", "other" ]
    ].freeze

    def customer_account_reference?(ref)
      ref = ref.to_s.strip
      return false if ref.blank?
      INTERNAL_ACCOUNT_PREFIXES.none? { |p| ref.start_with?(p) }
    end

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
      customer_txns = posting_batch.account_transactions
        .select { |at| customer_account_reference?(at.account_reference) }
      by_ref = customer_txns.group_by { |at| at.account_reference.to_s.strip }

      by_ref.map do |ref, transactions|
        total_credit = transactions.select { |t| t.direction == "credit" }.sum(&:amount_cents)
        total_debit = transactions.select { |t| t.direction == "debit" }.sum(&:amount_cents)
        account = Account.find_by(account_number: ref)

        if account
          net_cents = total_credit - total_debit
          current_balance = account.balance_cents
          previous_balance = current_balance - net_cents
          {
            account: account,
            account_reference: ref,
            previous_balance_cents: previous_balance,
            credit_cents: total_credit,
            debit_cents: total_debit,
            pending_balance_cents: current_balance
          }
        else
          {
            account: nil,
            account_reference: ref,
            previous_balance_cents: nil,
            credit_cents: total_credit,
            debit_cents: total_debit,
            pending_balance_cents: nil
          }
        end
      end.sort_by { |s| s[:account_reference] }
    end

    def check_items_from_metadata(posting_batch)
      meta = posting_batch.metadata
      return [] unless meta.is_a?(Hash)

      meta = meta.with_indifferent_access
      items = meta["check_items"] || meta.dig("check_cashing", "check_items")
      Array(items).map { |i| i.is_a?(Hash) ? i.with_indifferent_access : {} }
    end

    def add_business_days(date, days)
      d = date.to_date
      count = 0
      while count < days
        d += 1
        count += 1 unless d.saturday? || d.sunday?
      end
      d
    end

    def deposit_availability_rows(posting_batch, cash_in_from_cash_cents, check_items, cash_back_cents: 0)
      as_of = posting_batch.committed_at&.to_date || Date.current
      rows = []
      remaining_cash_back = [ cash_back_cents.to_i, 0 ].max

      immediate_cents = [ cash_in_from_cash_cents.to_i, 0 ].max
      if immediate_cents.positive?
        deduct = [ remaining_cash_back, immediate_cents ].min
        remaining_cash_back -= deduct
        net_cents = immediate_cents - deduct
        rows << { label: "Immediate", date: as_of, amount_cents: net_cents } if net_cents.positive?
      end

      held = check_items.select { |i| (i["hold_reason"] || i[:hold_reason]).to_s.present? }
      non_held = check_items.reject { |i| (i["hold_reason"] || i[:hold_reason]).to_s.present? }
      non_held_total = non_held.sum { |i| (i["amount_cents"] || i[:amount_cents] || 0).to_i }

      if non_held_total.positive?
        first_250_cents = [ 25_000, non_held_total ].min
        rest_cents = non_held_total - first_250_cents
        next_biz = add_business_days(as_of, 1)
        two_biz = add_business_days(as_of, 2)

        deduct_first250 = [ remaining_cash_back, first_250_cents ].min
        remaining_cash_back -= deduct_first250
        net_first250 = first_250_cents - deduct_first250
        rows << { label: next_biz.strftime("%B %-d, %Y"), date: next_biz, amount_cents: net_first250 } if net_first250.positive?

        deduct_rest = [ remaining_cash_back, rest_cents ].min
        remaining_cash_back -= deduct_rest
        net_rest = rest_cents - deduct_rest
        rows << { label: two_biz.strftime("%B %-d, %Y"), date: two_biz, amount_cents: net_rest } if net_rest.positive?
      end

      held_by_date = held.group_by { |i| (i["hold_until"] || i[:hold_until]).to_s }
      held_rows = held_by_date.each_with_object([]) do |(date_str, items), arr|
        next if date_str.blank?
        date = Date.parse(date_str) rescue nil
        next unless date
        amt = items.sum { |i| (i["amount_cents"] || i[:amount_cents] || 0).to_i }
        arr << { label: date.strftime("%B %-d, %Y"), date: date, amount_cents: amt }
      end.sort_by { |r| r[:date] }

      held_rows.each do |row|
        deduct = [ remaining_cash_back, row[:amount_cents] ].min
        remaining_cash_back -= deduct
        net_cents = row[:amount_cents] - deduct
        rows << { **row, amount_cents: net_cents } if net_cents.positive?
      end

      rows.sort_by { |r| [ r[:label] == "Immediate" ? 0 : 1, r[:date] ] }
    end

    def receipt_money(cents)
      number_to_currency((cents || 0) / 100.0)
    end

    def check_hold_indicator(item)
      check_type = (item["check_type"] || item[:check_type]).to_s
      letter = check_type == "on_us" ? "O" : "T"
      hold_reason = (item["hold_reason"] || item[:hold_reason]).to_s
      asterisk = hold_reason.present? ? "*" : ""
      "#{letter}#{asterisk}"
    end

    def served_party_from_metadata(posting_batch)
      meta = posting_batch.metadata
      return nil unless meta.is_a?(Hash)

      meta = meta.with_indifferent_access
      served = meta["served_party"] || meta.dig("check_cashing")
      return nil unless served.is_a?(Hash)

      served = served.with_indifferent_access
      party_id = served["party_id"] || served[:party_id]
      party = Party.find_by(id: party_id) if party_id.present?
      id_type = (served["id_type"] || served[:id_type]).to_s.presence
      id_number = (served["id_number"] || served[:id_number]).to_s.presence

      display_name = if party.present?
        party.display_name
      elsif id_type.present? && id_number.present?
        masked = id_number.length > 4 ? "****#{id_number[-4, 4]}" : "****"
        "Non-customer (#{id_type.titleize}: #{masked})"
      else
        nil
      end

      {
        party: party,
        party_id: party_id,
        id_type: id_type,
        id_number: id_number,
        display_name: display_name
      }
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
