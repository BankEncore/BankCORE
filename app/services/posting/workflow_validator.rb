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
          add_served_party_errors!(errors, params)
          if transaction_type == "deposit"
            total_deposit = Array(entries).select { |e| (e[:side] || e["side"]) == "debit" }.sum { |e| (e[:amount_cents] || e["amount_cents"]).to_i }
            cash_back = params[:cash_back_cents].to_i
            errors << "Cash back cannot exceed total deposit" if total_deposit.positive? && cash_back > total_deposit
          end
        when "transfer"
          add_served_party_errors!(errors, params)
          if entries.blank?
            errors << "From account reference is required" if params[:primary_account_reference].blank?
            errors << "To account reference is required" if params[:counterparty_account_reference].blank?
          end
          fee_cents = params[:fee_cents].to_i
          amount_cents = params[:amount_cents].to_i
          errors << "Transfer fee cannot exceed transfer amount" if fee_cents.positive? && fee_cents > amount_cents
        when "check_cashing"
          add_served_party_errors!(errors, params)
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
        when "draft"
          add_served_party_errors!(errors, params)
          validate_draft(errors, params, mode: mode)
        when "misc_receipt"
          add_served_party_errors!(errors, params)
          validate_misc_receipt(errors, params, mode: mode)
        when "bill_payment"
          add_served_party_errors!(errors, params)
          validate_bill_payment(errors, params, mode: mode)
        when "vault_transfer"
          validate_vault_transfer(errors, params)
        end

        validate_denomination_breakdown!(errors, params, transaction_type)

        errors
      end

      private
        def add_served_party_errors!(errors, params)
          return if params[:party_id].to_s.strip.present?

          errors << "Party is required. Use search or 'Add new non-customer' for walk-ins."
        end

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

        def validate_misc_receipt(errors, params, mode:)
          type_id = params[:misc_receipt_type_id].to_s.presence
          income_ref = params[:income_account_reference].to_s.strip.presence
          errors << "Misc receipt type or income account reference is required" if type_id.blank? && income_ref.blank?

          type = MiscReceiptType.find_by(id: type_id) if type_id.present?
          memo_required = type&.memo_required?
          errors << "Memo is required" if memo_required && params[:memo].to_s.strip.blank?

          amount_cents = params[:amount_cents].to_i

          misc_cash_cents = params[:misc_cash_cents].to_i
          misc_account_cents = params[:misc_account_cents].to_i
          check_items = Array(params[:check_items]).map { |item| item.to_h.symbolize_keys }
          check_total = check_items.sum { |item| item[:amount_cents].to_i }
          total_payment = misc_cash_cents + misc_account_cents + check_total
          errors << "Payment (cash + account + checks) must equal amount" unless total_payment == amount_cents

          return unless mode == :validate

          if type_id.present? && type.nil?
            errors << "Invalid misc receipt type"
          elsif type_id.blank? && income_ref.blank?
            errors << "Income account reference or valid misc receipt type is required"
          end
          errors << "Cash account reference is required" if misc_cash_cents.positive? && params[:cash_account_reference].blank?
          errors << "Primary account reference is required" if misc_account_cents.positive? && params[:primary_account_reference].blank?
        end

        def validate_bill_payment(errors, params, mode:)
          payee_id = params[:payee_id].to_s.presence
          errors << "Payee is required" if payee_id.blank?
          errors << "Payee reference is required" if params[:payee_reference].to_s.strip.blank?

          payment_cents = params[:payment_cents].to_i
          fee_cents = params[:fee_cents].to_i
          total_due_cents = payment_cents + fee_cents
          amount_cents = params[:amount_cents].to_i

          errors << "Payment amount must be greater than zero" unless payment_cents.positive?
          errors << "Fee cannot be negative" if fee_cents.negative?
          errors << "Amount must equal payment plus fee" unless amount_cents == total_due_cents

          bill_payment_cash_cents = params[:bill_payment_cash_cents].to_i
          bill_payment_account_cents = params[:bill_payment_account_cents].to_i
          check_items = Array(params[:check_items]).map { |item| item.to_h.symbolize_keys }
          check_total_cents = check_items.sum { |item| item[:amount_cents].to_i }
          total_payment_cents = bill_payment_cash_cents + bill_payment_account_cents + check_total_cents
          errors << "Payment (cash + account + checks) must equal total due" unless total_payment_cents == total_due_cents

          payee = BillPayee.find_by(id: payee_id) if payee_id.present?
          memo_required = payee&.memo_required?
          errors << "Memo is required" if memo_required && params[:memo].to_s.strip.blank?

          return unless mode == :validate

          if payee_id.present? && payee.nil?
            errors << "Invalid payee"
          elsif payee_id.present? && !payee.is_active
            errors << "Payee is not active"
          end
          errors << "Cash account reference is required" if bill_payment_cash_cents.positive? && params[:cash_account_reference].blank?
          errors << "Primary account reference is required" if bill_payment_account_cents.positive? && params[:primary_account_reference].blank?
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

        def validate_denomination_breakdown!(errors, params, transaction_type)
          workflow = Teller::WorkflowRegistry.fetch(transaction_type)
          mode = workflow&.dig(:denomination_breakdown_mode)
          return unless mode.to_s == "required"

          amount_cents = params[:amount_cents].to_i
          return if amount_cents.zero?

          denom_total = denomination_total_from_params(params)
          if denom_total.zero?
            errors << "Denomination breakdown is required"
          elsif denom_total != amount_cents
            errors << "Denomination total must equal amount"
          end
        end

        def denomination_total_from_params(params)
          raw = Array(params[:denomination_lines])
          catalog = CashDenomination.enabled.index_by(&:id)
          total = 0
          raw.each do |line|
            line = line.to_h.symbolize_keys
            id = line[:cash_denomination_id].to_s.strip.presence&.to_i
            next if id.blank? || catalog[id].nil?

            amt = line[:amount_cents].to_i
            qty = line[:qty].to_s.strip.presence&.to_i
            if qty.present? && qty >= 0
              denom = catalog[id]
              amt = qty * denom.unit_value_cents if denom
            end
            total += amt
          end
          total
        end
    end
  end
end
