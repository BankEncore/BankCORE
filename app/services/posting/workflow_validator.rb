module Posting
  class WorkflowValidator
    class << self
      def errors(posting_params, mode: :validate)
        params = posting_params.to_h.symbolize_keys
        transaction_type = params[:transaction_type].to_s
        entries = Array(params[:entries])

        errors = []
        errors << "Transaction type is required" if transaction_type.blank?
        errors << "Amount must be greater than zero" unless params[:amount_cents].to_i.positive?

        return errors if transaction_type.blank?

        unless Teller::WorkflowRegistry.supported_transaction_type?(transaction_type)
          errors << "Transaction type is not supported"
          return errors
        end

        case transaction_type
        when "deposit", "withdrawal"
          errors << "Primary account reference is required" if params[:primary_account_reference].blank?
          if transaction_type == "deposit"
            total_deposit = Array(entries).select { |e| (e[:side] || e["side"]) == "debit" }.sum { |e| (e[:amount_cents] || e["amount_cents"]).to_i }
            cash_back = params[:cash_back_cents].to_i
            errors << "Cash back cannot exceed total deposit" if total_deposit.positive? && cash_back > total_deposit
          end
        when "transfer"
          if entries.blank?
            errors << "From account reference is required" if params[:primary_account_reference].blank?
            errors << "To account reference is required" if params[:counterparty_account_reference].blank?
          end
          fee_cents = params[:fee_cents].to_i
          amount_cents = params[:amount_cents].to_i
          errors << "Transfer fee cannot exceed transfer amount" if fee_cents.positive? && fee_cents > amount_cents
        when "check_cashing"
          errors << "Party is required" if params[:party_id].blank?
          raw_items = Array(params[:check_items])
          check_items = raw_items.select { |item| (item[:amount_cents] || item["amount_cents"]).to_i.positive? }
          errors << "At least one check with amount greater than zero is required" if check_items.empty?
          if check_items.any?
            check_total = check_items.sum { |item| (item[:amount_cents] || item["amount_cents"]).to_i }
            fee_cents = params[:fee_cents].to_i
            errors << "Fee cannot exceed check total" if fee_cents > check_total
            net_payout = check_total - fee_cents
            errors << "Net cash payout must be greater than zero" if net_payout <= 0
          end
          if params[:party_id].blank?
            errors << "ID type is required when no party is selected" if params[:id_type].blank?
            errors << "ID number is required when no party is selected" if params[:id_number].blank?
          end
        when "draft"
          validate_draft(errors, params, mode: mode)
        when "vault_transfer"
          validate_vault_transfer(errors, params)
        end

        errors
      end

      private
        def validate_draft(errors, params, mode:)
          draft_amount_cents = params[:draft_amount_cents].to_i
          draft_fee_cents = params[:draft_fee_cents].to_i
          draft_cash_cents = params[:draft_cash_cents].to_i
          draft_account_cents = params[:draft_account_cents].to_i
          check_items = Array(params[:check_items]).map { |item| item.to_h.symbolize_keys }
          draft_check_cents = check_items.sum { |item| item[:amount_cents].to_i }
          total_due_cents = draft_amount_cents + draft_fee_cents
          total_payment_cents = draft_cash_cents + draft_account_cents + draft_check_cents

          errors << "Draft amount must be greater than zero" unless draft_amount_cents.positive?
          errors << "Payee name is required" if params[:draft_payee_name].blank?
          errors << "Instrument number is required" if params[:draft_instrument_number].blank?
          errors << "Payment (cash + checks + account) must equal total due" unless total_payment_cents == total_due_cents

          if mode == :validate
            errors << "Liability account reference is required" if params[:draft_liability_account_reference].blank?
            errors << "Cash account reference is required" if draft_cash_cents.positive? && params[:cash_account_reference].blank?
            errors << "Primary account reference is required" if draft_account_cents.positive? && params[:primary_account_reference].blank?
          end
        end

        def validate_vault_transfer(errors, params)
          direction = params[:vault_transfer_direction].to_s
          source_reference = params[:vault_transfer_source_cash_account_reference].to_s
          destination_reference = params[:vault_transfer_destination_cash_account_reference].to_s
          reason_code = params[:vault_transfer_reason_code].to_s
          memo = params[:vault_transfer_memo].to_s

          unless direction.in?([ "drawer_to_vault", "vault_to_drawer", "vault_to_vault" ])
            errors << "Vault transfer direction is required"
          end

          errors << "Reason code is required" if reason_code.blank?
          errors << "Memo is required for Other reason code" if reason_code == "other" && memo.blank?

          if direction == "vault_to_vault"
            errors << "Source cash account reference is required" if source_reference.blank?
            errors << "Destination cash account reference is required" if destination_reference.blank?
          elsif direction == "vault_to_drawer"
            errors << "Source cash account reference is required" if source_reference.blank?
          elsif direction == "drawer_to_vault"
            errors << "Destination cash account reference is required" if destination_reference.blank?
          end

          if source_reference.present? && destination_reference.present? && source_reference == destination_reference
            errors << "Source and destination cash account references must differ"
          end
        end
    end
  end
end
