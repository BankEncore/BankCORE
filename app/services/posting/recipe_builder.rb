module Posting
  class RecipeBuilder
    def initialize(posting_params:, default_cash_account_reference:)
      @posting_params = posting_params.to_h.symbolize_keys
      @default_cash_account_reference = default_cash_account_reference.to_s
    end

    def posting_metadata
      transaction_type = posting_params[:transaction_type].to_s

      return check_cashing_metadata if transaction_type == "check_cashing"
      return vault_transfer_metadata if transaction_type == "vault_transfer"
      return draft_metadata if transaction_type == "draft"
      return transfer_metadata if transaction_type == "transfer"
      return {} unless transaction_type == "deposit"

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

    def normalized_entries
      explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
      entries = explicit_entries.present? ? sanitized_explicit_entries(explicit_entries) : generated_entries

      enrich_entries_with_structured_fields(entries)
    end

    private
      attr_reader :posting_params, :default_cash_account_reference

      def check_cashing_metadata
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        check_amount_cents = check_items.sum { |item| item[:amount_cents].to_i }
        fee_cents = posting_params[:fee_cents].to_i
        net_cash_payout_cents = check_amount_cents - fee_cents

        {
          check_cashing: {
            check_items: check_items.map do |item|
              {
                routing: item[:routing].to_s,
                account: item[:account].to_s,
                number: item[:number].to_s,
                account_reference: item[:account_reference].to_s,
                amount_cents: item[:amount_cents].to_i
              }
            end,
            check_amount_cents: check_amount_cents,
            fee_cents: fee_cents,
            net_cash_payout_cents: net_cash_payout_cents,
            party_id: posting_params[:party_id].to_s,
            fee_income_account_reference: fee_income_account_reference,
            id_type: posting_params[:id_type].to_s,
            id_number: posting_params[:id_number].to_s
          }
        }
      end

      def transfer_metadata
        fee_cents = posting_params[:fee_cents].to_i
        return {} if fee_cents <= 0

        {
          fee_cents: fee_cents,
          fee_income_account_reference: transfer_fee_income_account_reference
        }
      end

      def vault_transfer_metadata
        {
          vault_transfer: {
            direction: vault_transfer_direction,
            source_cash_account_reference: vault_transfer_source_reference,
            destination_cash_account_reference: vault_transfer_destination_reference,
            reason_code: posting_params[:vault_transfer_reason_code].to_s,
            memo: posting_params[:vault_transfer_memo].to_s
          }
        }
      end

      def draft_metadata
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        metadata = {
          draft: {
            draft_amount_cents: posting_params[:draft_amount_cents].to_i,
            fee_cents: posting_params[:draft_fee_cents].to_i,
            draft_cash_cents: posting_params[:draft_cash_cents].to_i,
            draft_account_cents: posting_params[:draft_account_cents].to_i,
            payee_name: posting_params[:draft_payee_name].to_s,
            instrument_number: posting_params[:draft_instrument_number].to_s,
            liability_account_reference: draft_liability_account_reference,
            fee_income_account_reference: draft_fee_income_account_reference
          }
        }
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
        end if check_items.any?
        metadata
      end

      def sanitized_explicit_entries(explicit_entries)
        transaction_type = posting_params[:transaction_type].to_s
        amount_cents = posting_params[:amount_cents].to_i
        primary_account_reference = posting_params[:primary_account_reference].to_s

        case transaction_type
        when "deposit"
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
        when "withdrawal"
          generated_entries
        else
          explicit_entries
        end
      end

      def generated_entries
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
          fee_cents = posting_params[:fee_cents].to_i
          net_to_counterparty = [ amount_cents - fee_cents, 0 ].max
          entries = [
            { side: "debit", account_reference: primary_account_reference, amount_cents: amount_cents },
            { side: "credit", account_reference: counterparty_account_reference, amount_cents: net_to_counterparty }
          ]
          entries << { side: "credit", account_reference: transfer_fee_income_account_reference, amount_cents: fee_cents } if fee_cents.positive?
          entries
        when "vault_transfer"
          source_reference = vault_transfer_source_reference
          destination_reference = vault_transfer_destination_reference

          return [] if source_reference.blank? || destination_reference.blank?
          return [] if source_reference == destination_reference

          [
            { side: "debit", account_reference: destination_reference, amount_cents: amount_cents },
            { side: "credit", account_reference: source_reference, amount_cents: amount_cents }
          ]
        when "check_cashing"
          check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
          check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
          check_amount_cents = check_items.sum { |item| item[:amount_cents].to_i }
          fee_cents = posting_params[:fee_cents].to_i
          net_cash_payout_cents = check_amount_cents - fee_cents

          return [] if check_items.empty?
          return [] unless net_cash_payout_cents.positive?
          return [] unless amount_cents == net_cash_payout_cents

          entries = check_items.map do |item|
            { side: "debit", account_reference: item[:account_reference].to_s, amount_cents: item[:amount_cents].to_i }
          end
          entries << { side: "credit", account_reference: default_cash_account_reference, amount_cents: net_cash_payout_cents }
          entries << { side: "credit", account_reference: fee_income_account_reference, amount_cents: fee_cents } if fee_cents.positive?

          entries
        when "draft"
          draft_amount_cents = posting_params[:draft_amount_cents].to_i
          draft_fee_cents = posting_params[:draft_fee_cents].to_i
          draft_cash_cents = posting_params[:draft_cash_cents].to_i
          draft_account_cents = posting_params[:draft_account_cents].to_i
          check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
          draft_check_cents = check_items.sum { |item| item[:amount_cents].to_i }
          liability_account_reference = draft_liability_account_reference

          return [] unless draft_amount_cents.positive?
          return [] if liability_account_reference.blank?

          total_due_cents = draft_amount_cents + draft_fee_cents
          total_payment_cents = draft_cash_cents + draft_account_cents + draft_check_cents
          return [] unless total_payment_cents == total_due_cents

          entries = []

          if draft_cash_cents.positive? && default_cash_account_reference.present?
            entries << { side: "debit", account_reference: default_cash_account_reference, amount_cents: draft_cash_cents }
          end

          check_items.select { |item| item[:amount_cents].to_i.positive? }.each do |item|
            entries << { side: "debit", account_reference: item[:account_reference].to_s, amount_cents: item[:amount_cents].to_i }
          end

          primary_used = primary_account_reference.present? &&
            primary_account_reference != "0" &&
            primary_account_reference != "acct:0"
          if draft_account_cents.positive? && primary_used
            entries << { side: "debit", account_reference: primary_account_reference, amount_cents: draft_account_cents }
          end

          entries << { side: "credit", account_reference: liability_account_reference, amount_cents: draft_amount_cents }

          if draft_fee_cents.positive?
            entries << { side: "credit", account_reference: draft_fee_income_account_reference, amount_cents: draft_fee_cents }
          end

          entries
        else
          []
        end
      end

      def fee_income_account_reference
        posting_params[:fee_income_account_reference].presence || "income:check_cashing_fee"
      end

      def transfer_fee_income_account_reference
        posting_params[:fee_income_account_reference].presence || "income:transfer_fee"
      end

      def draft_liability_account_reference
        posting_params[:draft_liability_account_reference].presence || "official_check:outstanding"
      end

      def draft_fee_income_account_reference
        posting_params[:draft_fee_income_account_reference].presence || "income:draft_fee"
      end

      def enrich_entries_with_structured_fields(entries)
        entries.map do |entry|
          metadata = check_metadata_for_entry(entry)
          parsed = AccountReferenceParser.parse(entry[:account_reference], metadata: metadata)
          entry.merge(
            reference_type: parsed[:reference_type],
            reference_identifier: parsed[:reference_identifier],
            check_routing_number: parsed[:check_routing_number],
            check_account_number: parsed[:check_account_number],
            check_number: parsed[:check_number],
            check_type: parsed[:check_type]
          )
        end
      end

      def check_metadata_for_entry(entry)
        ref = entry[:account_reference].to_s
        return {} unless ref.start_with?("check:")

        check_items = all_check_items_from_params
        item = check_items.find { |ci| (ci[:account_reference] || ci["account_reference"]).to_s == ref }
        return {} if item.blank?

        ct = (item[:check_type] || item["check_type"]).to_s.presence || "transit"
        { "check_type" => ct }
      end

      def all_check_items_from_params
        items = Array(posting_params[:check_items]).map { |i| i.to_h.symbolize_keys }
        return items if items.any?

        check_cashing = posting_params[:check_cashing] || posting_params["check_cashing"]
        Array(check_cashing&.dig("check_items") || check_cashing&.dig(:check_items)).map { |i| i.to_h.symbolize_keys }
      end

      def vault_transfer_direction
        direction = posting_params[:vault_transfer_direction].to_s
        return direction if direction.in?([ "drawer_to_vault", "vault_to_drawer", "vault_to_vault" ])

        ""
      end

      def vault_transfer_source_reference
        case vault_transfer_direction
        when "drawer_to_vault"
          default_cash_account_reference
        when "vault_to_drawer", "vault_to_vault"
          posting_params[:vault_transfer_source_cash_account_reference].to_s
        else
          ""
        end
      end

      def vault_transfer_destination_reference
        case vault_transfer_direction
        when "drawer_to_vault", "vault_to_vault"
          posting_params[:vault_transfer_destination_cash_account_reference].to_s
        when "vault_to_drawer"
          default_cash_account_reference
        else
          ""
        end
      end
  end
end
