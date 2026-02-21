module PostingRequestBuilder
  extend ActiveSupport::Concern

  private
    def posting_metadata(posting_params)
      return {} unless posting_params[:transaction_type].to_s == "deposit"

      check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
      check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
      return {} if check_items.empty?

      {
        check_items: check_items.map do |item|
          {
            routing: item[:routing].to_s,
            account: item[:account].to_s,
            number: item[:number].to_s,
            account_reference: item[:account_reference].to_s,
            amount_cents: item[:amount_cents].to_i,
            hold_reason: item[:hold_reason].to_s,
            hold_until: item[:hold_until].to_s
          }
        end
      }
    end

    def normalized_entries(posting_params)
      explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
      return sanitized_explicit_entries(posting_params, explicit_entries) if explicit_entries.present?

      generated_entries(posting_params)
    end

    def sanitized_explicit_entries(posting_params, explicit_entries)
      transaction_type = posting_params[:transaction_type].to_s
      cash_reference = default_cash_account_reference
      amount_cents = posting_params[:amount_cents].to_i
      primary_account_reference = posting_params[:primary_account_reference].to_s

      case transaction_type
      when "deposit"
        debit_entries = explicit_entries.select { |entry| entry[:side] == "debit" }
        normalized_debits = debit_entries.map do |entry|
          account_reference = entry[:account_reference].to_s
          normalized_reference = account_reference.start_with?("check:") ? account_reference : cash_reference

          entry.merge(account_reference: normalized_reference)
        end

        normalized_debits + [ { side: "credit", account_reference: primary_account_reference, amount_cents: amount_cents } ]
      when "withdrawal"
        generated_entries(posting_params)
      else
        explicit_entries
      end
    end

    def generated_entries(posting_params)
      transaction_type = posting_params[:transaction_type].to_s
      amount_cents = posting_params[:amount_cents].to_i
      primary_account_reference = posting_params[:primary_account_reference].to_s
      counterparty_account_reference = posting_params[:counterparty_account_reference].to_s
      cash_account_reference = transaction_type.in?([ "deposit", "withdrawal" ]) ? default_cash_account_reference : posting_params[:cash_account_reference].presence || default_cash_account_reference

      case transaction_type
      when "deposit"
        [
          { side: "debit", account_reference: cash_account_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: primary_account_reference, amount_cents: amount_cents }
        ]
      when "withdrawal"
        [
          { side: "debit", account_reference: primary_account_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: cash_account_reference, amount_cents: amount_cents }
        ]
      when "transfer"
        [
          { side: "debit", account_reference: primary_account_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: counterparty_account_reference, amount_cents: amount_cents }
        ]
      else
        []
      end
    end

    def default_cash_account_reference
      return "cash:unassigned" if current_teller_session&.cash_location.blank?

      "cash:#{current_teller_session.cash_location.code}"
    end

    def approval_required?(posting_params)
      posting_params[:amount_cents].to_i >= 100_000
    end
end
