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
        validate_misc_additions!(errors, params, transaction_type)

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
          misc_total = misc_additions_total_cents(params)
          draft_cash_cents = params[:draft_cash_cents].to_i
          draft_account_cents = params[:draft_account_cents].to_i
          check_items = Array(params[:check_items]).map { |item| item.to_h.symbolize_keys }
          draft_check_cents = check_items.sum { |item| item[:amount_cents].to_i }
          total_due_cents = draft_amount_cents + draft_fee_cents + misc_total
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
          misc_total = misc_additions_total_cents(params)

          misc_cash_cents = params[:misc_cash_cents].to_i
          misc_account_cents = params[:misc_account_cents].to_i
          check_items = Array(params[:check_items]).map { |item| item.to_h.symbolize_keys }
          check_total = check_items.sum { |item| item[:amount_cents].to_i }
          total_payment = misc_cash_cents + misc_account_cents + check_total
          total_due = amount_cents + misc_total
          errors << "Payment (cash + account + checks) must equal amount" unless total_payment == total_due

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
          misc_total = misc_additions_total_cents(params)
          total_due_cents = payment_cents + fee_cents + misc_total
          amount_cents = params[:amount_cents].to_i

          errors << "Payment amount must be greater than zero" unless payment_cents.positive?
          errors << "Fee cannot be negative" if fee_cents.negative?
          errors << "Amount must equal payment plus fee plus misc additions" unless amount_cents == total_due_cents

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

        def validate_misc_additions!(errors, params, transaction_type)
          raw = params[:misc_additions] || params["misc_additions"]
          misc_additions = Array(raw).map { |e| e.to_h.symbolize_keys }
          return if misc_additions.blank?

          return unless TransactionMiscReceiptDefault::SUPPORTED_TRANSACTION_TYPES.include?(transaction_type)

          defaults = TransactionMiscReceiptDefault.for_transaction_type(transaction_type).includes(:misc_receipt_type)

          misc_additions.each do |line|
            type_id = (line[:misc_receipt_type_id] || line["misc_receipt_type_id"]).to_s.presence
            errors << "Misc addition requires misc_receipt_type_id" if type_id.blank?

            type = MiscReceiptType.find_by(id: type_id) if type_id.present?
            if type_id.present? && type.nil?
              errors << "Invalid misc receipt type for misc addition"
            elsif type.present? && type.memo_required?
              memo = (line[:memo] || line["memo"]).to_s.strip
              errors << "Memo is required for #{type.label}" if memo.blank?
            end

            amount_charged = (line[:amount_charged_cents] || line["amount_charged_cents"]).to_i
            errors << "Misc addition amount cannot be negative" if amount_charged.negative?
          end

          defaults.each do |default|
            next unless default.mandatory?

            found = misc_additions.any? do |line|
              ((line[:misc_receipt_type_id] || line["misc_receipt_type_id"]).to_s == default.misc_receipt_type_id.to_s) &&
                (line[:amount_charged_cents] || line["amount_charged_cents"]).to_i.positive?
            end
            errors << "Mandatory fee #{default.misc_receipt_type&.label} is required" unless found
          end

          misc_additions.each do |line|
            type_id = (line[:misc_receipt_type_id] || line["misc_receipt_type_id"]).to_s.presence
            next if type_id.blank?

            default = defaults.find { |d| d.misc_receipt_type_id.to_s == type_id }
            next if default.blank? || !default.fixed?

            amount_charged = (line[:amount_charged_cents] || line["amount_charged_cents"]).to_i
            waived = !! (line[:waived] || line["waived"])
            expected = default.effective_default_amount_cents || 0

            errors << "Fee #{default.misc_receipt_type&.label} cannot be waived" if waived
            errors << "Fee #{default.misc_receipt_type&.label} amount must be #{expected / 100.0}" if !waived && amount_charged != expected
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

        def misc_additions_total_cents(params)
          raw = params[:misc_additions] || params["misc_additions"]
          Array(raw).sum { |line| (line[:amount_charged_cents] || line["amount_charged_cents"]).to_i }
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
