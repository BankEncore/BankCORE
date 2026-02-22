module PostingRequestBuilder
  extend ActiveSupport::Concern

  private
    def posting_metadata(posting_params)
      transaction_type = posting_params[:transaction_type].to_s

      return check_cashing_metadata(posting_params) if transaction_type == "check_cashing"
      return vault_transfer_metadata(posting_params) if transaction_type == "vault_transfer"
      return draft_metadata(posting_params) if transaction_type == "draft"
      return {} unless transaction_type == "deposit"

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

    def check_cashing_metadata(posting_params)
      check_amount_cents = posting_params[:check_amount_cents].to_i
      fee_cents = posting_params[:fee_cents].to_i
      net_cash_payout_cents = check_amount_cents - fee_cents

      {
        check_cashing: {
          check_amount_cents: check_amount_cents,
          fee_cents: fee_cents,
          net_cash_payout_cents: net_cash_payout_cents,
          settlement_account_reference: posting_params[:settlement_account_reference].to_s,
          fee_income_account_reference: fee_income_account_reference(posting_params),
          check_number: posting_params[:check_number].to_s,
          routing_number: posting_params[:routing_number].to_s,
          account_number: posting_params[:account_number].to_s,
          payer_name: posting_params[:payer_name].to_s,
          presenter_type: posting_params[:presenter_type].to_s,
          id_type: posting_params[:id_type].to_s,
          id_number: posting_params[:id_number].to_s
        }
      }
    end

    def vault_transfer_metadata(posting_params)
      {
        vault_transfer: {
          direction: vault_transfer_direction(posting_params),
          source_cash_account_reference: vault_transfer_source_reference(posting_params),
          destination_cash_account_reference: vault_transfer_destination_reference(posting_params),
          reason_code: posting_params[:vault_transfer_reason_code].to_s,
          memo: posting_params[:vault_transfer_memo].to_s
        }
      }
    end

    def draft_metadata(posting_params)
      {
        draft: {
          funding_source: draft_funding_source(posting_params),
          draft_amount_cents: posting_params[:draft_amount_cents].to_i,
          fee_cents: posting_params[:draft_fee_cents].to_i,
          payee_name: posting_params[:draft_payee_name].to_s,
          instrument_number: posting_params[:draft_instrument_number].to_s,
          liability_account_reference: draft_liability_account_reference(posting_params),
          fee_income_account_reference: draft_fee_income_account_reference(posting_params)
        }
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
      when "vault_transfer"
        source_reference = vault_transfer_source_reference(posting_params)
        destination_reference = vault_transfer_destination_reference(posting_params)

        return [] if source_reference.blank? || destination_reference.blank?
        return [] if source_reference == destination_reference

        [
          { side: "debit", account_reference: destination_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: source_reference, amount_cents: amount_cents }
        ]
      when "check_cashing"
        check_amount_cents = posting_params[:check_amount_cents].to_i
        fee_cents = posting_params[:fee_cents].to_i
        net_cash_payout_cents = check_amount_cents - fee_cents
        settlement_account_reference = posting_params[:settlement_account_reference].to_s

        return [] unless check_amount_cents.positive?
        return [] unless net_cash_payout_cents.positive?
        return [] if settlement_account_reference.blank?
        return [] unless amount_cents == net_cash_payout_cents

        entries = [
          { side: "debit", account_reference: settlement_account_reference, amount_cents: check_amount_cents },
          { side: "credit", account_reference: default_cash_account_reference, amount_cents: net_cash_payout_cents }
        ]

        if fee_cents.positive?
          entries << { side: "credit", account_reference: fee_income_account_reference(posting_params), amount_cents: fee_cents }
        end

        entries
      when "draft"
        draft_amount_cents = posting_params[:draft_amount_cents].to_i
        draft_fee_cents = posting_params[:draft_fee_cents].to_i
        funding_source = draft_funding_source(posting_params)
        liability_account_reference = draft_liability_account_reference(posting_params)

        return [] unless draft_amount_cents.positive?
        return [] if liability_account_reference.blank?

        funding_reference = if funding_source == "cash"
          default_cash_account_reference
        else
          primary_account_reference
        end

        return [] if funding_reference.blank?

        entries = [
          { side: "debit", account_reference: funding_reference, amount_cents: draft_amount_cents },
          { side: "credit", account_reference: liability_account_reference, amount_cents: draft_amount_cents }
        ]

        if draft_fee_cents.positive?
          fee_income_reference = draft_fee_income_account_reference(posting_params)
          entries << { side: "debit", account_reference: funding_reference, amount_cents: draft_fee_cents }
          entries << { side: "credit", account_reference: fee_income_reference, amount_cents: draft_fee_cents }
        end

        entries
      else
        []
      end
    end

    def fee_income_account_reference(posting_params)
      posting_params[:fee_income_account_reference].presence || "income:check_cashing_fee"
    end

    def draft_funding_source(posting_params)
      source = posting_params[:draft_funding_source].to_s
      return "cash" if source == "cash"

      "account"
    end

    def draft_liability_account_reference(posting_params)
      posting_params[:draft_liability_account_reference].presence || "official_check:outstanding"
    end

    def draft_fee_income_account_reference(posting_params)
      posting_params[:draft_fee_income_account_reference].presence || "income:draft_fee"
    end

    def vault_transfer_direction(posting_params)
      direction = posting_params[:vault_transfer_direction].to_s
      return direction if direction.in?([ "drawer_to_vault", "vault_to_drawer", "vault_to_vault" ])

      ""
    end

    def vault_transfer_source_reference(posting_params)
      direction = vault_transfer_direction(posting_params)

      case direction
      when "drawer_to_vault"
        default_cash_account_reference
      when "vault_to_drawer"
        posting_params[:vault_transfer_source_cash_account_reference].to_s
      when "vault_to_vault"
        posting_params[:vault_transfer_source_cash_account_reference].to_s
      else
        ""
      end
    end

    def vault_transfer_destination_reference(posting_params)
      direction = vault_transfer_direction(posting_params)

      case direction
      when "drawer_to_vault"
        posting_params[:vault_transfer_destination_cash_account_reference].to_s
      when "vault_to_drawer"
        default_cash_account_reference
      when "vault_to_vault"
        posting_params[:vault_transfer_destination_cash_account_reference].to_s
      else
        ""
      end
    end

    def default_cash_account_reference
      return "cash:unassigned" if current_teller_session&.cash_location.blank?

      "cash:#{current_teller_session.cash_location.code}"
    end

    def approval_required?(posting_params)
      approval_policy_trigger(posting_params).present?
    end

    def approval_policy_trigger(posting_params)
      return "amount_threshold" if posting_params[:amount_cents].to_i >= approval_amount_threshold_cents

      nil
    end

    def approval_policy_context(posting_params)
      trigger = approval_policy_trigger(posting_params)
      return {} if trigger.blank?

      {
        trigger: trigger,
        threshold_cents: approval_amount_threshold_cents,
        amount_cents: posting_params[:amount_cents].to_i,
        transaction_type: posting_params[:transaction_type].to_s
      }
    end

    def approval_amount_threshold_cents
      100_000
    end
end
