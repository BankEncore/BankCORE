module Posting
  module Recipes
    class DepositRecipe < BaseRecipe
      def normalized_entries
        explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
        explicit_entries.present? ? sanitized_explicit_entries(explicit_entries) : generated_entries
      end

      def posting_metadata
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        total_deposit = posting_params[:amount_cents].to_i + posting_params[:cash_back_cents].to_i
        cash_back_cents = [ posting_params[:cash_back_cents].to_i, total_deposit ].min

        metadata = {}
        metadata[:cash_back_cents] = cash_back_cents if cash_back_cents.positive?
        if check_items.any?
          metadata[:check_items] = check_items.map do |item|
            {
              routing: item[:routing].to_s,
              account: item[:account].to_s,
              number: item[:number].to_s,
              account_reference: item[:account_reference].to_s,
              amount_cents: item[:amount_cents].to_i,
              check_type: item[:check_type].to_s.presence || "transit",
              hold_reason: item[:hold_reason].to_s,
              hold_until: item[:hold_until].to_s
            }
          end
        end

        metadata.presence || {}
      end

      private

      def sanitized_explicit_entries(explicit_entries)
        amount_cents = posting_params[:amount_cents].to_i
        primary_account_reference = posting_params[:primary_account_reference].to_s

        debit_entries = explicit_entries.select { |entry| entry[:side] == "debit" }
        normalized_debits = debit_entries.map do |entry|
          account_reference = entry[:account_reference].to_s
          normalized_reference = account_reference.start_with?("check:") ? account_reference : default_cash_account_reference

          entry.merge(account_reference: normalized_reference)
        end

        cash_back_cents = [ posting_params[:cash_back_cents].to_i, posting_params[:amount_cents].to_i + posting_params[:cash_back_cents].to_i ].min
        credits = []
        credits << { side: "credit", account_reference: default_cash_account_reference, amount_cents: cash_back_cents } if cash_back_cents.positive?
        credits << { side: "credit", account_reference: primary_account_reference, amount_cents: amount_cents }
        normalized_debits + credits
      end

      def generated_entries
        amount_cents = posting_params[:amount_cents].to_i
        primary_account_reference = posting_params[:primary_account_reference].to_s
        cash_account_reference = default_cash_account_reference

        [
          { side: "debit", account_reference: cash_account_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: primary_account_reference, amount_cents: amount_cents }
        ]
      end
    end
  end
end
