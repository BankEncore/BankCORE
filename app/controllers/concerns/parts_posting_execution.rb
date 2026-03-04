# frozen_string_literal: true

module PartsPostingExecution
  extend ActiveSupport::Concern

  include TellerPostingExecution

  private
    def execute_posting(forced_transaction_type: nil)
      request_params = posting_params.to_h.symbolize_keys
      request_params[:transaction_type] = forced_transaction_type if forced_transaction_type.present?
      request_params[:request_id] = request_params[:request_id].presence || "server-#{Time.current.to_i}-#{SecureRandom.hex(4)}"

      validation_errors = Posting::WorkflowValidator.errors(request_params, mode: :post)
      if validation_errors.present?
        render json: { ok: false, error: validation_errors.first }, status: :unprocessable_entity
        return
      end

      advisory_check = AdvisoryService.check_posting_allowed(
        primary_account_reference: request_params[:primary_account_reference],
        party_id: request_params[:party_id],
        acknowledged_advisory_ids: params[:acknowledged_advisory_ids]
      )
      unless advisory_check[:allowed]
        status = advisory_check[:status] || :unprocessable_entity
        error = advisory_check[:error] || "Posting not allowed"
        error += ": #{advisory_check[:advisory]&.title}" if advisory_check[:advisory]&.title.present?
        render json: { ok: false, error: error }, status: status
        return
      end

      approved_by_user_id = nil
      if approval_required?(request_params)
        token = request_params[:approval_token].to_s
        if token.blank?
          render json: { ok: false, error: "Supervisor approval is required for this amount" }, status: :unprocessable_entity
          return
        end

        begin
          payload = approval_verifier.verify(token)
          if payload["request_id"].to_s != request_params[:request_id].to_s
            render json: { ok: false, error: "Approval token does not match request" }, status: :unprocessable_entity
            return
          end
          approved_by_user_id = payload["supervisor_user_id"]
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          render json: { ok: false, error: "Approval token is invalid or expired" }, status: :unprocessable_entity
          return
        end
      end

      metadata = posting_metadata(request_params).dup
      denom_lines = Array(request_params[:denomination_lines])
        .map { |l| l.to_h.symbolize_keys }
        .select { |l| (l[:amount_cents] || 0).to_i.positive? }
      if denom_lines.any?
        metadata["denomination_lines"] = denom_lines.map { |l| l.slice(:cash_denomination_id, :qty, :amount_cents) }
      end

      entries = parts_entries(request_params)

      posting_batch = Posting::Engine.new(
        user: Current.user,
        teller_session: current_teller_session,
        branch: current_branch,
        workstation: current_workstation,
        request_id: request_params[:request_id],
        transaction_type: request_params[:transaction_type],
        amount_cents: request_params[:amount_cents],
        entries: entries,
        metadata: metadata,
        currency: request_params[:currency].presence || "USD",
        approved_by_user_id: approved_by_user_id
      ).call

      render json: {
        ok: true,
        posting_batch_id: posting_batch.id,
        teller_transaction_id: posting_batch.teller_transaction_id,
        request_id: request_params[:request_id]
      }
    rescue Posting::Engine::Error, ActiveRecord::RecordInvalid, Posting::Parts::PartBuilder::ValidationError => error
      render json: { ok: false, error: error.message }, status: :unprocessable_entity
    end

    def parts_entries(request_params)
      flow_type = request_params[:transaction_type].to_s
      params = parts_params_for(flow_type, request_params)
      Posting::Parts::PartBuilder.build_entries(flow_type: flow_type, **params)
    end

    def parts_params_for(flow_type, request_params)
      cash_ref = default_cash_account_reference

      case flow_type
      when "check_cashing"
        {
          check_items: Array(request_params[:check_items]).map(&:to_h).map(&:symbolize_keys),
          fee_cents: request_params[:fee_cents].to_i,
          cash_account_reference: request_params[:cash_account_reference].presence || cash_ref,
          fee_income_account_reference: request_params[:fee_income_account_reference]
        }
      when "withdrawal"
        {
          amount_cents: request_params[:amount_cents].to_i,
          fee_cents: request_params[:fee_cents].to_i,
          primary_account_reference: request_params[:primary_account_reference].to_s,
          cash_account_reference: request_params[:cash_account_reference].presence || cash_ref,
          fee_income_account_reference: request_params[:fee_income_account_reference]
        }
      when "transfer"
        {
          amount_cents: request_params[:amount_cents].to_i,
          fee_cents: request_params[:fee_cents].to_i,
          primary_account_reference: request_params[:primary_account_reference].to_s,
          counterparty_account_reference: request_params[:counterparty_account_reference].to_s,
          fee_income_account_reference: request_params[:fee_income_account_reference]
        }
      when "deposit"
        {
          amount_cents: request_params[:amount_cents].to_i,
          cash_back_cents: request_params[:cash_back_cents].to_i,
          fee_cents: request_params[:fee_cents].to_i,
          check_items: Array(request_params[:check_items]).map(&:to_h).map(&:symbolize_keys),
          primary_account_reference: request_params[:primary_account_reference].to_s,
          cash_account_reference: request_params[:cash_account_reference].presence || cash_ref,
          fee_income_account_reference: request_params[:fee_income_account_reference]
        }
      when "vault_transfer"
        source = resolve_vault_transfer_source(request_params)
        dest = resolve_vault_transfer_destination(request_params)
        {
          amount_cents: request_params[:amount_cents].to_i,
          source_cash_account_reference: source,
          destination_cash_account_reference: dest
        }
      when "misc_receipt"
        {
          amount_cents: request_params[:amount_cents].to_i,
          misc_cash_cents: request_params[:misc_cash_cents].to_i,
          misc_account_cents: request_params[:misc_account_cents].to_i,
          check_items: Array(request_params[:check_items]).map(&:to_h).map(&:symbolize_keys),
          primary_account_reference: request_params[:primary_account_reference].to_s,
          cash_account_reference: request_params[:cash_account_reference].presence || cash_ref,
          income_account_reference: resolve_misc_receipt_income_ref(request_params)
        }
      when "draft"
        {
          draft_amount_cents: request_params[:draft_amount_cents].to_i,
          draft_fee_cents: request_params[:draft_fee_cents].to_i,
          draft_cash_cents: request_params[:draft_cash_cents].to_i,
          draft_account_cents: request_params[:draft_account_cents].to_i,
          check_items: Array(request_params[:check_items]).map(&:to_h).map(&:symbolize_keys),
          primary_account_reference: request_params[:primary_account_reference].to_s,
          cash_account_reference: request_params[:cash_account_reference].presence || cash_ref,
          draft_liability_account_reference: request_params[:draft_liability_account_reference].presence || "official_check:outstanding",
          draft_fee_income_account_reference: request_params[:draft_fee_income_account_reference]
        }
      when "bill_payment"
        {
          payment_cents: request_params[:payment_cents].to_i,
          fee_cents: request_params[:fee_cents].to_i,
          bill_payment_cash_cents: request_params[:bill_payment_cash_cents].to_i,
          bill_payment_account_cents: request_params[:bill_payment_account_cents].to_i,
          check_items: Array(request_params[:check_items]).map(&:to_h).map(&:symbolize_keys),
          primary_account_reference: request_params[:primary_account_reference].to_s,
          cash_account_reference: request_params[:cash_account_reference].presence || cash_ref,
          liability_account_reference: resolve_bill_payment_liability_ref(request_params),
          fee_income_account_reference: request_params[:fee_income_account_reference]
        }
      else
        raise ArgumentError, "Unsupported flow type for Parts: #{flow_type}"
      end
    end

    def resolve_vault_transfer_source(request_params)
      direction = request_params[:vault_transfer_direction].to_s
      case direction
      when "drawer_to_vault"
        request_params[:cash_account_reference].presence || default_cash_account_reference
      when "vault_to_drawer", "vault_to_vault"
        request_params[:vault_transfer_source_cash_account_reference].to_s
      else
        request_params[:vault_transfer_from_reference].presence ||
          request_params[:vault_transfer_source_cash_account_reference].to_s
      end
    end

    def resolve_vault_transfer_destination(request_params)
      direction = request_params[:vault_transfer_direction].to_s
      case direction
      when "drawer_to_vault", "vault_to_vault"
        request_params[:vault_transfer_destination_cash_account_reference].to_s
      when "vault_to_drawer"
        request_params[:cash_account_reference].presence || default_cash_account_reference
      else
        request_params[:vault_transfer_to_reference].presence ||
          request_params[:vault_transfer_destination_cash_account_reference].to_s
      end
    end

    def resolve_misc_receipt_income_ref(request_params)
      ref = request_params[:income_account_reference].to_s.strip
      return ref if ref.present?

      type_id = request_params[:misc_receipt_type_id].to_s.presence
      return "" if type_id.blank?

      type = MiscReceiptType.find_by(id: type_id)
      type&.income_account_reference.to_s
    end

    def resolve_bill_payment_liability_ref(request_params)
      ref = request_params[:liability_account_reference].to_s.strip
      return ref if ref.present?

      payee_id = request_params[:payee_id].to_s.presence
      return "" if payee_id.blank?

      payee = BillPayee.find_by(id: payee_id)
      payee&.liability_account_reference.to_s
    end

    def normalized_entries(posting_params)
      parts_entries(posting_params.to_h.symbolize_keys)
    end
end
