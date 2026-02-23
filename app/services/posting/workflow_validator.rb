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
        when "transfer"
          if entries.blank?
            errors << "From account reference is required" if params[:primary_account_reference].blank?
            errors << "To account reference is required" if params[:counterparty_account_reference].blank?
          end
        when "check_cashing"
          if mode == :validate
            errors << "Primary account reference is required" if entries.blank? && params[:primary_account_reference].blank?
          end
          errors << "ID type is required" if params[:id_type].blank?
          errors << "ID number is required" if params[:id_number].blank?
        when "draft"
          validate_draft(errors, params, mode: mode)
        when "vault_transfer"
          validate_vault_transfer(errors, params)
        end

        errors
      end

      private
        def validate_draft(errors, params, mode:)
          funding_source = params[:draft_funding_source].to_s
          errors << "Draft amount must be greater than zero" unless params[:draft_amount_cents].to_i.positive?
          errors << "Payee name is required" if params[:draft_payee_name].blank?
          errors << "Instrument number is required" if params[:draft_instrument_number].blank?
          if mode == :validate
            errors << "Liability account reference is required" if params[:draft_liability_account_reference].blank?
          end

          if funding_source == "cash"
            if mode == :validate
              errors << "Cash account reference is required" if params[:cash_account_reference].blank?
            end
          else
            errors << "Primary account reference is required" if params[:primary_account_reference].blank?
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
